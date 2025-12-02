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

# 확인할 서버 이름 패턴 (일반적인 이름들)
# 필요시 여기에 패턴 추가
SERVER_PATTERNS=(
    "jenkins"
    "bastion"
    "gitlab"
    "harbor"
    "vault"
    # gcp-gcby 프로젝트
    "gcby-gs01"
    "gcby-gs02"
    "gcby-gs03"
    "gcby-gs04"
    "gcby-gs05"
    "gcby-db01"
    "gcby-cache01"
    # jsj-game-n 프로젝트
    "game-gs01"
    "game-gs02"
    "game-gs03"
    "game-db01"
    "game-cache01"
    # 일반 패턴
    "web01"
    "web02"
    "api01"
    "api02"
    "worker01"
    "worker02"
)

# ============================================================================
# 색상
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

check_dns_tools() {
    if ! command -v dig &> /dev/null && ! command -v nslookup &> /dev/null; then
        log_error "dig 또는 nslookup이 필요합니다"
        log_info "설치: sudo yum install -y bind-utils  # RHEL/Rocky"
        log_info "      sudo apt install -y dnsutils    # Debian/Ubuntu"
        exit 1
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

get_vm_list() {
    local vm_data=()
    local current_hostname=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)

    log_info "DNS에서 VM 탐색 중..."

    for server_name in "${SERVER_PATTERNS[@]}"; do
        # 자기 자신은 제외
        if [[ "$server_name" == "$current_hostname" ]] || [[ "$server_name" == "bastion" ]]; then
            continue
        fi

        # DNS 조회
        local ip=$(resolve_hostname "$server_name")

        if [[ -n "$ip" ]] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # 역할 추론 (이름 기반)
            local role=""
            local purpose=""

            case "$server_name" in
                *jenkins*) role="ci-cd"; purpose="Jenkins" ;;
                *gitlab*) role="scm"; purpose="GitLab" ;;
                *harbor*) role="registry"; purpose="Harbor" ;;
                *vault*) role="secrets"; purpose="Vault" ;;
                *gs*) role="game"; purpose="Game Server" ;;
                *db*) role="database"; purpose="Database" ;;
                *cache*) role="cache"; purpose="Redis/Memcached" ;;
                *web*) role="web"; purpose="Web Server" ;;
                *api*) role="api"; purpose="API Server" ;;
                *worker*) role="worker"; purpose="Worker" ;;
                *) role="unknown"; purpose="VM" ;;
            esac

            vm_data+=("$server_name|$ip|$role|$purpose")
            log_info "발견: ${CYAN}$server_name${NC} → $ip"
        fi
    done

    printf '%s\n' "${vm_data[@]}"
}

display_vm_menu() {
    local vm_list=("$@")

    if [[ ${#vm_list[@]} -eq 0 ]]; then
        log_error "사용 가능한 VM을 찾을 수 없습니다"
        echo "" >&2
        log_info "서버 패턴에 VM이 없거나 DNS에 등록되지 않았습니다"
        log_info "스크립트의 SERVER_PATTERNS 배열에 서버 이름을 추가하세요"
        exit 1
    fi

    echo "" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${GREEN}           사용 가능한 VM (DNS 자동 탐색)                      ${NC}" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2

    PS3=$'\n'"접속할 VM을 선택하세요 (종료: 'q'): "

    local options=()

    for vm_entry in "${vm_list[@]}"; do
        IFS='|' read -r name ip role purpose <<< "$vm_entry"

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

            if [[ $selected_idx -ge 0 ]] && [[ $selected_idx -lt ${#vm_list[@]} ]]; then
                # 원래 stdout(fd 3)으로 결과 출력
                echo "${vm_list[$selected_idx]}" >&3
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

    log_info "${CYAN}$vm_name${NC} 에 접속 중..."
    log_info "대상: ${CYAN}$target${NC} ($vm_ip)"
    echo ""

    # 직접 SSH 연결
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        "${VM_USER}@${target}"
}

# ============================================================================
# 메인
# ============================================================================

main() {
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Cloud DNS 기반 자동화 SSH 접속                         ║${NC}"
    echo -e "${GREEN}║       배스천 호스트 → 내부 VM                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # DNS 도구 확인
    check_dns_tools

    # VM 목록 가져오기
    mapfile -t vm_list < <(get_vm_list)

    if [[ ${#vm_list[@]} -eq 0 ]]; then
        exit 1
    fi

    echo ""
    log_success "${#vm_list[@]}개의 VM을 찾았습니다"

    # 메뉴 표시
    selected_vm=$(display_vm_menu "${vm_list[@]}")

    # 디버깅: 선택된 VM 정보 출력
    if [[ -z "$selected_vm" ]]; then
        log_error "선택된 VM 정보가 비어있습니다"
        log_error "Debug: selected_vm='$selected_vm'"
        exit 1
    fi

    log_info "Debug: selected_vm='$selected_vm'" >&2

    # 선택한 VM 정보 파싱
    IFS='|' read -r name ip role purpose <<< "$selected_vm"

    log_info "Debug: name='$name', ip='$ip', role='$role', purpose='$purpose'" >&2

    echo ""
    log_success "선택: ${CYAN}$name${NC}"

    # VM 접속
    connect_to_vm "$name" "$ip"
}

main "$@"
