#!/usr/bin/env bash
set -euo pipefail

# SSM 실행 환경 감지 및 로깅 설정
LOG_FILE="/var/log/alloy-install-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# SSM 환경 변수 확인
IS_SSM="${AWS_SSM_INSTANCE_ID:-false}"
if [[ "$IS_SSM" != "false" ]]; then
    echo "[INFO] Running in SSM environment: $AWS_SSM_INSTANCE_ID"
fi

# 기본 매개변수 설정
FORCE_REINSTALL="${1:-false}"

###############################################################################
# Configuration Variables
###############################################################################
ACCOUNT_ID="aws-rag"
JOB_NAME="prod"
MIMIR_URL="http://ftt-lgtm.x433.com:9009/api/v1/push"
TENANT_HEADER="ftt-lgtm"
LOKI_URL="http://ftt-lgtm.x433.com:3100/loki/api/v1/push"
LOKI_TENANT="ftt-lgtm"
TEMPO_HOST="http://ftt-lgtm.x433.com:4317"
PYROSCOPE_URL="http://ftt-lgtm.x433.com:4040"
ALLOY_UI_PORT="12345"
ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"
ALLOY_VERSION="1.10.0"

# SSM용 타임아웃 설정
CURL_TIMEOUT=10
IMDS_TIMEOUT=5

###############################################################################
# 에러 핸들러
###############################################################################
error_handler() {
    local line_no=$1
    local exit_code=$2
    echo "[ERROR] Script failed at line $line_no with exit code $exit_code"
    echo "[ERROR] Check log file: $LOG_FILE"
    exit $exit_code
}
trap 'error_handler $LINENO $?' ERR

###############################################################################
# 진행 상황 보고 함수 (SSM용)
###############################################################################
report_progress() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
    # SSM 환경에서는 CloudWatch로도 전송
    if [[ "$IS_SSM" != "false" ]]; then
        logger -t "alloy-install" "$message"
    fi
}

###############################################################################
# 기존 Alloy 완전 제거 함수
###############################################################################
cleanup_existing_alloy() {
    report_progress "Checking and removing existing Alloy installation..."
    
    # 서비스 중지 및 비활성화
    if systemctl is-active --quiet alloy 2>/dev/null; then
        report_progress "Stopping Alloy service..."
        systemctl stop alloy || true
    fi
    
    if systemctl is-enabled --quiet alloy 2>/dev/null; then
        report_progress "Disabling Alloy service..."
        systemctl disable alloy || true
    fi
    
    # OS 감지 및 패키지 매니저 선택
    if grep -q "Amazon Linux release 2023" /etc/os-release 2>/dev/null; then
        PKG="dnf"
    elif grep -q "Amazon Linux release 2" /etc/os-release 2>/dev/null; then
        PKG="yum"
    elif grep -q "Rocky Linux" /etc/os-release 2>/dev/null; then
        PKG="dnf"
    else
        PKG="yum"
    fi
    
    # 패키지 제거 (비대화형 모드 강제)
    if rpm -q alloy &>/dev/null; then
        report_progress "Removing existing Alloy package..."
        DEBIAN_FRONTEND=noninteractive $PKG -y remove alloy 2>&1 || true
    fi
    
    # systemd 오버라이드 설정 제거
    if [[ -d /etc/systemd/system/alloy.service.d ]]; then
        report_progress "Removing systemd override settings..."
        rm -rf /etc/systemd/system/alloy.service.d
    fi
    
    # 설정 디렉터리 백업 후 제거
    if [[ -d /etc/alloy ]]; then
        local backup_dir="/etc/alloy.backup.$(date +%Y%m%d_%H%M%S)"
        report_progress "Backing up existing config to $backup_dir"
        mv /etc/alloy "$backup_dir" 2>/dev/null || true
    fi
    
    # 데이터 디렉터리 백업 후 제거
    if [[ -d /var/lib/alloy ]]; then
        local backup_dir="/var/lib/alloy.backup.$(date +%Y%m%d_%H%M%S)"
        report_progress "Backing up existing data to $backup_dir"
        mv /var/lib/alloy "$backup_dir" 2>/dev/null || true
    fi
    
    # systemd 데몬 리로드
    systemctl daemon-reload
    systemctl reset-failed alloy 2>/dev/null || true
    
    report_progress "Existing Alloy removal completed"
}

###############################################################################
# 시스템 계정/그룹 설정
###############################################################################
setup_system_accounts() {
    report_progress "Setting up system accounts and groups..."
    
    if ! getent group alloy >/dev/null; then
        groupadd --system alloy
    fi
    
    if ! id -u alloy >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /sbin/nologin --gid alloy alloy
    fi
    
    # journald 읽기용 보조 그룹 확보 및 alloy 계정에 부여
    for g in systemd-journal adm; do
        getent group "$g" >/dev/null || groupadd --system "$g"
    done
    usermod -aG systemd-journal,adm alloy
}

###############################################################################
# 메타데이터 수집 (SSM 환경 최적화)
###############################################################################
collect_metadata() {
    report_progress "Collecting system metadata..."
    
    # OS 타입 감지
    if grep -q "Amazon Linux release 2023" /etc/os-release 2>/dev/null; then
        OS_TYPE="amz23"
        PKG="dnf"
    elif grep -q "Amazon Linux release 2" /etc/os-release 2>/dev/null; then
        OS_TYPE="amz2"
        PKG="yum"
    elif grep -q "Rocky Linux" /etc/os-release 2>/dev/null; then
        OS_TYPE="rocky"
        PKG="dnf"
    else
        OS_TYPE="unknown"
        PKG="yum"
    fi
    
    # EC2 메타데이터 수집 (더 안전한 방법)
    INSTANCE_TYPE="unknown"
    if [[ "${OS_TYPE:-}" == "amz"* ]]; then
        # IMDSv2 토큰 획득 시도
        IMDS_TOKEN=""
        if curl -sf -m $IMDS_TIMEOUT -X PUT "http://169.254.169.254/latest/api/token" \
           -H "X-aws-ec2-metadata-token-ttl-seconds: 60" > /tmp/imds_token 2>/dev/null; then
            IMDS_TOKEN=$(cat /tmp/imds_token)
            rm -f /tmp/imds_token
        fi
        
        # 인스턴스 타입 획득
        if [[ -n "$IMDS_TOKEN" ]]; then
            INSTANCE_TYPE=$(curl -sf -m $IMDS_TIMEOUT \
                "http://169.254.169.254/latest/meta-data/instance-type" \
                -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" 2>/dev/null || echo "unknown")
        else
            # IMDSv1 폴백 시도
            INSTANCE_TYPE=$(curl -sf -m $IMDS_TIMEOUT \
                "http://169.254.169.254/latest/meta-data/instance-type" 2>/dev/null || echo "unknown")
        fi
    else
        # 온프레미스/IDC 환경
        INSTANCE_TYPE=$(
            cat /sys/class/dmi/id/product_name 2>/dev/null | tr ' ' '_' || \
            dmidecode -s system-product-name 2>/dev/null | tr ' ' '_' || \
            echo "ftt-lgtm-physical-server"
        )
    fi
    
    # 호스트명과 IP 수집
    HOSTNAME="${HOSTNAME:-$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo 'localhost')}"
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || \
               ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1 || \
               echo "127.0.0.1")
    
    report_progress "Metadata collected: OS=$OS_TYPE, Instance=$INSTANCE_TYPE, Host=$HOSTNAME"
}

###############################################################################
# Alloy 패키지 설치
###############################################################################
install_alloy_package() {
    report_progress "Installing Alloy package..."
    
    # 기존 Alloy가 설치되어 있으면 제거
    if rpm -q alloy &>/dev/null; then
        cleanup_existing_alloy
    fi
    
    # Grafana 저장소 설정 정리
    rm -f /etc/yum.repos.d/grafana.repo
    rm -f /etc/pki/rpm-gpg/grafana.key
    rpm -e gpg-pubkey-grafana 2>/dev/null || true
    
    # GPG 키 다운로드 및 임포트 (재시도 로직 포함)
    report_progress "Downloading Grafana GPG key..."
    mkdir -p /etc/pki/rpm-gpg
    
    local retry=0
    local max_retries=3
    while [[ $retry -lt $max_retries ]]; do
        if curl -sSL --connect-timeout $CURL_TIMEOUT --max-time 30 \
           https://rpm.grafana.com/gpg.key -o /etc/pki/rpm-gpg/grafana.key; then
            break
        fi
        retry=$((retry + 1))
        report_progress "GPG key download failed, retry $retry/$max_retries"
        sleep 2
    done
    
    if [[ ! -f /etc/pki/rpm-gpg/grafana.key ]]; then
        report_progress "ERROR: Failed to download GPG key after $max_retries attempts"
        exit 1
    fi
    
    rpm --import /etc/pki/rpm-gpg/grafana.key
    
    # 저장소 설정
    cat <<'REPO' | tee /etc/yum.repos.d/grafana.repo >/dev/null
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
enabled=1
repo_gpgcheck=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/grafana.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
timeout=30
REPO
    
    # 패키지 설치 (비대화형 모드, 재시도 포함)
    report_progress "Installing Alloy version $ALLOY_VERSION..."
    retry=0
    while [[ $retry -lt $max_retries ]]; do
        if DEBIAN_FRONTEND=noninteractive $PKG -y install "alloy-${ALLOY_VERSION}" 2>&1; then
            break
        elif DEBIAN_FRONTEND=noninteractive $PKG -y install alloy 2>&1; then
            break
        fi
        retry=$((retry + 1))
        report_progress "Package installation failed, retry $retry/$max_retries"
        sleep 5
    done
    
    if ! rpm -q alloy &>/dev/null; then
        report_progress "ERROR: Failed to install Alloy after $max_retries attempts"
        exit 1
    fi
    
    $PKG clean all
    
    # 설치 확인
    ALLOY_INSTALLED_VERSION=$(/usr/bin/alloy --version 2>&1 | head -n1 || echo "unknown")
    report_progress "Alloy installed: $ALLOY_INSTALLED_VERSION"
}

###############################################################################
# Alloy 설정 생성
###############################################################################
create_alloy_config() {
    report_progress "Creating Alloy configuration..."
    
    # 데이터 디렉터리 생성
    mkdir -p /var/lib/alloy/data
    chown -R alloy:alloy /var/lib/alloy
    
    # 설정 디렉터리 생성
    mkdir -p /etc/alloy
    
    # Alloy 설정 파일 생성
    cat <<EOF | tee "$ALLOY_CONFIG_PATH" >/dev/null
logging {
  level  = "warn"
  format = "logfmt"
}

// ========== LOKI (로그) ==========
loki.write "default" {
  endpoint {
    url       = "${LOKI_URL}"
    tenant_id = "${LOKI_TENANT}"
  }
}

// journald 라벨 변환 + “조건부 드롭”(권고 #3)
loki.relabel "journald_labels" {
  forward_to = [loki.process.journal_enrich.receiver]

  rule {
    source_labels = ["__journal_priority"]
    regex        = "^$"
    action       = "drop"
  }

  rule {
    source_labels = ["__journal_priority"]
    regex        = "^(0|1|2|3|4|5|6|7)$"
    action       = "keep"
  }

  rule {
    source_labels = ["__journal_syslog_identifier"]
    regex        = "(.+)"
    target_label = "service_name"
    replacement  = "\$1"  
  }

  rule {
    source_labels = ["__journal_priority"]
    regex        = "0|1|2"
    target_label = "level"
    replacement  = "critical"
  }
  rule {
    source_labels = ["__journal_priority"]
    regex        = "3"
    target_label = "level"
    replacement  = "error"
  }
  
  rule {
    source_labels = ["__journal_priority"]
    regex        = "4"
    target_label = "level"
    replacement  = "warning"
  }

  rule {
    source_labels = ["__journal_priority"]
    regex        = "5"
    target_label = "level"
    replacement  = "notice"
  }

  rule {
    source_labels = ["__journal_priority"]
    regex        = "6"
    target_label = "level"
    replacement  = "info"
  }

  rule {
    source_labels = ["__journal_priority"]
    regex        = "7"
    target_label = "level"
    replacement  = "debug"
  }

  rule {
    source_labels = ["__journal_syslog_identifier"]
    regex        = "(.+)"
    target_label = "service"
    replacement  = "\$1"
  }

  rule {
    source_labels = ["service"]
    regex        = "^$"
    target_label = "service"
    replacement  = "system"
  }
  
  rule {
    source_labels = ["__journal__systemd_unit"]
    regex        = "(.+)"
    target_label = "unit"
    replacement  = "\$1"
  }
  rule {
    source_labels = ["unit"]
    regex        = "^$"
    target_label = "unit"
    replacement  = "unknown"
  }
}

loki.source.journal "journald" {
  labels = {
    job = "syslog",
  }
  relabel_rules = loki.relabel.journald_labels.rules
  forward_to    = [loki.process.journal_enrich.receiver]
}

loki.process "journal_enrich" {
  forward_to = [loki.write.default.receiver]

  stage.match {
    selector = "{level=~\"debug|notice\"}"
    action   = "drop"
  }

  stage.static_labels {
    values = {
      account_id    = "${ACCOUNT_ID}",
      instance_type = "${INSTANCE_TYPE}",
      hostname      = "${HOSTNAME}",
      job_name      = "${JOB_NAME}",
    }
  }
}


// ========== PROMETHEUS (메트릭) ==========
prometheus.exporter.unix    "node" {}
prometheus.exporter.process "proc" {
  track_children = true

  matcher {
    name    = "{{.ExeBase}}"
    cmdline = [".+"]
  }

  // procfs_path = "/host/proc"
}

discovery.relabel "node_lbl" {
  targets = prometheus.exporter.unix.node.targets
  rule {
    action       = "replace"
    target_label = "instance_type"
    replacement  = "${INSTANCE_TYPE}"
  }
  rule {
    action       = "replace"
    target_label = "job"
    replacement  = "${ACCOUNT_ID}"
  }
}

discovery.relabel "proc_lbl" {
  targets = prometheus.exporter.process.proc.targets
  rule {
    action       = "replace"
    target_label = "instance_type"
    replacement  = "${INSTANCE_TYPE}"
  }
  rule {
    action       = "replace"
    target_label = "job"
    replacement  = "${ACCOUNT_ID}"
  }
}

prometheus.scrape "node" {
  targets         = discovery.relabel.node_lbl.output
  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

prometheus.scrape "proc" {
  targets         = discovery.relabel.proc_lbl.output
  scrape_interval = "30s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

prometheus.remote_write "mimir" {
  endpoint {
    url = "${MIMIR_URL}"
    headers = {
      "X-Scope-OrgID" = "${TENANT_HEADER}",
    }
    queue_config {
      max_samples_per_send = 2000
      batch_send_deadline  = "5s"
      capacity             = 10000
    }
  }
}

EOF
    
    # 설정 검증
    report_progress "Validating Alloy configuration..."
    if command -v /usr/bin/alloy >/dev/null 2>&1; then
        if ! /usr/bin/alloy validate "$ALLOY_CONFIG_PATH" 2>&1; then
            report_progress "ERROR: Alloy configuration validation failed"
            exit 1
        fi
        report_progress "Configuration validated successfully"
    else
        report_progress "WARNING: Alloy binary not found, skipping validation"
    fi
}

###############################################################################
# Systemd 서비스 설정
###############################################################################
configure_systemd_service() {
    report_progress "Configuring systemd service..."
    
    # systemd override 디렉터리 생성
    mkdir -p /etc/systemd/system/alloy.service.d
    
    # Override 설정 생성
    cat <<EOF | tee /etc/systemd/system/alloy.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/usr/bin/alloy run \\
  --server.http.listen-addr=0.0.0.0:${ALLOY_UI_PORT} \\
  --storage.path=/var/lib/alloy/data \\
  ${ALLOY_CONFIG_PATH}

SupplementaryGroups=systemd-journal adm
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3
EOF
    
    # Systemd 리로드 및 서비스 시작
    systemctl daemon-reload
    
    report_progress "Starting Alloy service..."
    systemctl enable alloy
    
    # 서비스 시작 및 상태 확인
    if systemctl start alloy; then
        sleep 3
        if systemctl is-active --quiet alloy; then
            report_progress "Alloy service started successfully"
        else
            report_progress "WARNING: Alloy service may not be running properly"
            systemctl status alloy --no-pager || true
        fi
    else
        report_progress "ERROR: Failed to start Alloy service"
        systemctl status alloy --no-pager || true
        exit 1
    fi
}

###############################################################################
# 설치 완료 보고
###############################################################################
report_completion() {
    echo ""
    echo "====================================================================="
    echo "✅ Alloy + LGTM Stack Installation Completed Successfully"
    echo "====================================================================="
    echo "System Info:"
    echo "  - OS Type      : ${OS_TYPE}"
    echo "  - Instance Type: ${INSTANCE_TYPE}"
    echo "  - Hostname     : ${HOSTNAME}"
    echo "  - Local IP     : ${LOCAL_IP}"
    echo ""
    echo "Service Endpoints:"
    echo "  - Alloy UI     : http://${LOCAL_IP}:${ALLOY_UI_PORT}/"
    echo "  - Metrics Jobs : ${ACCOUNT_ID}-node / ${ACCOUNT_ID}-proc → Mimir"
    echo "  - Logs         : syslog → Loki (${LOKI_URL})"
    echo ""
    echo "Service Status:"
    systemctl is-active alloy && echo "  - Alloy: Active" || echo "  - Alloy: Inactive"
    echo ""
    echo "Log File: $LOG_FILE"
    echo "====================================================================="
    
    # SSM 환경에서는 CloudWatch에도 완료 메시지 전송
    if [[ "$IS_SSM" != "false" ]]; then
        logger -t "alloy-install" -p user.info "Installation completed successfully"
    fi
}

###############################################################################
# 메인 실행 플로우
###############################################################################
main() {
    report_progress "Starting Alloy installation script..."
    report_progress "Force reinstall: $FORCE_REINSTALL"
    
    # 1. 시스템 계정 설정
    setup_system_accounts
    
    # 2. 메타데이터 수집
    collect_metadata
    
    # 3. Alloy 패키지 설치
    install_alloy_package
    
    # 4. Alloy 설정 생성
    create_alloy_config
    
    # 5. Systemd 서비스 설정
    configure_systemd_service
    
    # 6. 완료 보고
    report_completion
}

# 스크립트 실행
main "$@"