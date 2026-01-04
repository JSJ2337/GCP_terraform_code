#!/bin/bash
#
# Cloud DNS를 이용한 자동화 SSH 접속 스크립트
# 배스천 호스트 내부에서 실행
#

set -euo pipefail

# ============================================================================
# 설정
# ============================================================================

# VM 기본 SSH 사용자
VM_USER="${VM_USER:-delabs-adm}"

# 내부 DNS 도메인
DNS_DOMAIN="${DNS_DOMAIN:-delabsgames.internal}"

# Cloud DNS Zone 이름
DNS_ZONE="${DNS_ZONE:-delabsgames-internal}"

# Management 프로젝트 ID
MGMT_PROJECT="${MGMT_PROJECT:-delabs-gcp-mgmt}"

# 서버 패턴 (fallback용 - gcloud API 실패 시 사용)
SERVER_PATTERNS=(
    "jenkins"
    # gcp-gcby 프로젝트
    "gcby-gs01"
    "gcby-gs02"
    "gcby-live-gdb-m1"
    "gcby-live-redis"
    # gcp-web3 프로젝트
    "web3-www01"
    "web3-www02"
    "web3-www03"
    "web3-mint01"
    "web3-mint02"
    "web3-live-gdb-m1"
    "web3-live-redis"
)

# ============================================================================
# 색상
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================================================
# 함수
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

check_redis_cli() {
    # redis-cli 경로 찾기
    if command -v redis-cli &> /dev/null; then
        REDIS_CLI="redis-cli"
        return 0
    elif [ -x "/usr/local/bin/redis-cli" ]; then
        REDIS_CLI="/usr/local/bin/redis-cli"
        return 0
    elif [ -x "$HOME/redis-7.2.6/src/redis-cli" ]; then
        REDIS_CLI="$HOME/redis-7.2.6/src/redis-cli"
        return 0
    else
        log_warning "redis-cli가 설치되어 있지 않습니다"
        log_info "설치: sudo yum install -y redis  # RHEL/Rocky"
        log_info "      sudo apt install -y redis-tools  # Debian/Ubuntu"
        return 1
    fi
}

resolve_hostname() {
    local hostname="$1"
    local ip=""

    # dig 사용
    if command -v dig &> /dev/null; then
        ip=$(dig +short "${hostname}.${DNS_DOMAIN}" A 2>/dev/null | head -n1)
    # dig 없으면 nslookup 사용
    elif command -v nslookup &> /dev/null; then
        ip=$(nslookup "${hostname}.${DNS_DOMAIN}" 2>/dev/null | awk '/^Address: / { print $2 }' | head -n1)
    fi

    echo "$ip"
}

get_dns_records_via_api() {
    if ! command -v gcloud &> /dev/null; then
        return 1
    fi

    local records
    records=$(gcloud dns record-sets list \
        --zone="$DNS_ZONE" \
        --project="$MGMT_PROJECT" \
        --filter="type=A" \
        --format="csv[no-heading](name,rrdatas[0])" 2>/dev/null)

    if [[ -z "$records" ]]; then
        return 1
    fi

    echo "$records"
    return 0
}

classify_server() {
    local name="$1"
    local type="vm"
    local role="unknown"
    local purpose="VM"

    # Redis 감지
    if [[ "$name" =~ redis ]]; then
        type="redis"
        role="redis-cluster"

        if [[ "$name" =~ gcby ]]; then
            purpose="Redis Cluster [GCP-GCBY]"
        elif [[ "$name" =~ web3 ]]; then
            purpose="Redis Cluster [GCP-WEB3]"
        else
            purpose="Redis Cluster"
        fi

    # Database 감지
    elif [[ "$name" =~ (db|gdb|mysql|postgres) ]]; then
        type="vm"
        role="database"
        purpose="Database"

    # 나머지 VM 역할 분류
    else
        case "$name" in
            *jenkins*) role="ci-cd"; purpose="Jenkins" ;;
            *gitlab*) role="scm"; purpose="GitLab" ;;
            *harbor*) role="registry"; purpose="Harbor" ;;
            *vault*) role="secrets"; purpose="Vault" ;;
            *gs[0-9]*) role="game"; purpose="Game Server" ;;
            *cache*) role="cache"; purpose="Cache Server" ;;
            *www[0-9]*|*web[0-9]*) role="web"; purpose="Web Server" ;;
            *mint[0-9]*) role="api"; purpose="Mint API Server" ;;
            *api*) role="api"; purpose="API Server" ;;
            *worker*) role="worker"; purpose="Worker" ;;
            *bastion*) type="skip" ;;  # Bastion은 제외
        esac
    fi

    echo "$type|$role|$purpose"
}

get_server_list_via_api() {
    log_info "Cloud DNS API로 레코드 조회 시도 중..."

    local dns_records
    if ! dns_records=$(get_dns_records_via_api); then
        log_warning "Cloud DNS API 사용 불가 (권한 없음 또는 gcloud 미설치)"
        return 1
    fi

    local server_data=()
    local current_hostname=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)
    local vm_count=0
    local redis_count=0

    while IFS=',' read -r fqdn ip; do
        # FQDN에서 도메인 제거하여 호스트명만 추출
        local hostname="${fqdn%.${DNS_DOMAIN}.}"

        # IP 주소가 유효한지 확인
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi

        # 자기 자신 제외
        if [[ "$hostname" == "$current_hostname" ]] || [[ "$hostname" == "bastion" ]]; then
            continue
        fi

        # 서버 분류
        IFS='|' read -r type role purpose <<< "$(classify_server "$hostname")"

        # skip 타입은 제외
        if [[ "$type" == "skip" ]]; then
            continue
        fi

        # Database도 제외 (PSC Endpoint이므로 직접 SSH 불가)
        if [[ "$role" == "database" ]]; then
            continue
        fi

        server_data+=("$type|$hostname|$ip|$role|$purpose")

        if [[ "$type" == "redis" ]]; then
            ((redis_count++))
            log_info "발견: ${MAGENTA}$hostname${NC} → $ip (Redis)"
        else
            ((vm_count++))
            log_info "발견: ${CYAN}$hostname${NC} → $ip"
        fi

    done <<< "$dns_records"

    # 첫 번째 라인에 카운트 정보 출력 (STATS:vm_count:redis_count)
    echo "STATS:$vm_count:$redis_count"
    printf '%s\n' "${server_data[@]}"
    return 0
}

get_server_list_via_dig() {
    log_info "DNS 직접 조회 (dig/nslookup) 사용..."

    local server_data=()
    local current_hostname=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)
    local vm_count=0
    local redis_count=0

    for server_name in "${SERVER_PATTERNS[@]}"; do
        # 자기 자신은 제외
        if [[ "$server_name" == "$current_hostname" ]] || [[ "$server_name" == "bastion" ]]; then
            continue
        fi

        # DNS 조회
        local ip=$(resolve_hostname "$server_name")

        if [[ -n "$ip" ]] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # 서버 분류
            IFS='|' read -r type role purpose <<< "$(classify_server "$server_name")"

            # skip 타입은 제외
            if [[ "$type" == "skip" ]]; then
                continue
            fi

            # Database도 제외 (PSC Endpoint이므로 직접 SSH 불가)
            if [[ "$role" == "database" ]]; then
                continue
            fi

            server_data+=("$type|$server_name|$ip|$role|$purpose")

            if [[ "$type" == "redis" ]]; then
                ((redis_count++))
                log_info "발견: ${MAGENTA}$server_name${NC} → $ip (Redis)"
            else
                ((vm_count++))
                log_info "발견: ${CYAN}$server_name${NC} → $ip"
            fi
        fi
    done

    # 첫 번째 라인에 카운트 정보 출력 (STATS:vm_count:redis_count)
    echo "STATS:$vm_count:$redis_count"
    printf '%s\n' "${server_data[@]}"
}

get_server_list() {
    # 1단계: Cloud DNS API 시도
    if get_server_list_via_api; then
        return 0
    fi

    # 2단계: Fallback - dig/nslookup 사용
    log_info "Fallback: 패턴 기반 DNS 조회 사용"
    get_server_list_via_dig
}

display_menu() {
    local server_list=("$@")

    if [[ ${#server_list[@]} -eq 0 ]]; then
        log_error "사용 가능한 서버를 찾을 수 없습니다"
        echo "" >&2
        log_info "DNS에 등록된 서버가 없거나 조회할 수 없습니다"
        exit 1
    fi

    echo "" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${GREEN}           사용 가능한 서버 (DNS 자동 탐색)                    ${NC}" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2

    PS3=$'\n'"접속할 서버를 선택하세요 (종료: 'q'): "

    local options=()

    for entry in "${server_list[@]}"; do
        IFS='|' read -r type name ip role purpose <<< "$entry"

        local display="$name"
        local info="[IP: $ip]"

        if [[ -n "$role" ]] && [[ "$role" != "unknown" ]]; then
            info="$info [역할: $role]"
        fi

        if [[ -n "$purpose" ]]; then
            info="$info [$purpose]"
        fi

        options+=("$display $info")
    done

    options+=("종료")

    # stdout을 fd 3에 저장, stdout을 stderr로 리다이렉트
    exec 3>&1 1>&2

    select opt in "${options[@]}"; do
        if [[ "$REPLY" == "q" ]] || [[ "$opt" == "종료" ]]; then
            log_info "종료 중..."
            exit 0
        fi

        if [[ -n "$opt" ]]; then
            local selected_idx=$((REPLY - 1))

            if [[ $selected_idx -ge 0 ]] && [[ $selected_idx -lt ${#server_list[@]} ]]; then
                # 원래 stdout(fd 3)으로 결과 출력
                echo "${server_list[$selected_idx]}" >&3
                exec 1>&3 3>&-  # stdout 복원
                return 0
            else
                log_error "잘못된 선택입니다. 다시 시도해주세요."
            fi
        else
            log_error "잘못된 옵션입니다. 숫자를 입력하거나 'q'를 눌러 종료하세요."
        fi
    done
}

connect_to_vm() {
    local vm_name="$1"
    local vm_ip="$2"

    local target="${vm_name}.${DNS_DOMAIN}"

    log_info "${CYAN}$vm_name${NC} 에 SSH 접속 중..."
    log_info "대상: ${CYAN}$target${NC} ($vm_ip)"
    echo ""

    # 직접 SSH 연결
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        "${VM_USER}@${target}"
}

connect_to_redis() {
    local redis_name="$1"
    local redis_ip="$2"

    local target="${redis_name}.${DNS_DOMAIN}"

    log_info "${MAGENTA}$redis_name${NC} 에 Redis CLI 접속 중..."
    log_info "대상: ${MAGENTA}$target${NC} ($redis_ip:6379)"
    echo ""

    if ! check_redis_cli; then
        log_error "redis-cli를 설치 후 다시 시도하세요"
        exit 1
    fi

    # Redis CLI 연결
    log_success "Redis CLI 실행 중..."
    echo -e "${YELLOW}팁: 종료하려면 'exit' 또는 Ctrl+D${NC}" >&2
    echo ""

    # GCP Memorystore Redis Cluster는 TLS 필수
    $REDIS_CLI -h "$target" -p 6379 --tls --insecure
}

# ============================================================================
# 메인
# ============================================================================

main() {
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Cloud DNS 기반 자동화 접속 도구                        ║${NC}"
    echo -e "${GREEN}║       배스천 호스트 → 내부 VM / Redis Cluster                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 서버 목록 가져오기 (DNS 자동 탐색)
    mapfile -t all_output < <(get_server_list)

    if [[ ${#all_output[@]} -eq 0 ]]; then
        exit 1
    fi

    # 첫 번째 라인에서 카운트 정보 추출 (STATS:vm_count:redis_count)
    local stats_line="${all_output[0]}"
    if [[ "$stats_line" =~ ^STATS:([0-9]+):([0-9]+)$ ]]; then
        TOTAL_VM_COUNT="${BASH_REMATCH[1]}"
        TOTAL_REDIS_COUNT="${BASH_REMATCH[2]}"
        # 나머지는 서버 데이터
        server_list=("${all_output[@]:1}")
    else
        log_error "서버 목록 형식 오류"
        exit 1
    fi

    echo ""
    log_success "VM ${TOTAL_VM_COUNT}개, Redis Cluster ${TOTAL_REDIS_COUNT}개 발견"

    # 메뉴 표시
    selected=$(display_menu "${server_list[@]}")

    # 디버깅: 선택된 정보 출력
    if [[ -z "$selected" ]]; then
        log_error "선택된 서버 정보가 비어있습니다"
        exit 1
    fi

    # 선택한 서버 정보 파싱
    IFS='|' read -r type name ip role purpose <<< "$selected"

    echo ""
    log_success "선택: ${CYAN}$name${NC}"

    # 타입에 따라 접속
    if [[ "$type" == "redis" ]]; then
        connect_to_redis "$name" "$ip"
    else
        connect_to_vm "$name" "$ip"
    fi
}

main "$@"
