#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh - Rocky Linux 8.6 IDC Environment (Offline RPM Installation)
###############################################################################
ACCOUNT_ID="idc-spd"
JOB_NAME="prod"
TENANT_HEADER="ftt-lgtm"
LOKI_TENANT="ftt-lgtm"
TEMPO_HOST="http://ftt-lgtm.x433.com:4317"
MIMIR_URL="http://ftt-lgtm.x433.com:9009/api/v1/push"
LOKI_URL="http://ftt-lgtm.x433.com:3100/loki/api/v1/push"
PYROSCOPE_URL="http://ftt-lgtm.x433.com:4040"
ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"
ALLOY_UI_PORT="12345"
ALLOY_VERSION="1.10.0"               # 오프라인 RPM 버전
ALLOY_RPM_PATH="$HOME/alloy-1.10.0-1.amd64.rpm"

###############################################################################
# ─── 시스템 계정/그룹 ────────────────────────────────────────────────────────
if ! getent group alloy >/dev/null; then
  sudo groupadd --system alloy
fi

if ! id -u alloy >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /sbin/nologin --gid alloy alloy
fi

# journald 읽기용 보조 그룹 확보 및 alloy 계정에 부여
for g in systemd-journal adm; do
  getent group "$g" >/dev/null || sudo groupadd --system "$g"
done
sudo usermod -aG systemd-journal,adm alloy

###############################################################################
# ─── 설치 여부 확인 & 패키지 설치 ────────────────────────────────────────────
INSTALL_ALLOY=true
rpm -q alloy &>/dev/null && INSTALL_ALLOY=false

# Rocky Linux 8.6은 dnf 사용
PKG="dnf"

if $INSTALL_ALLOY; then
  # Rocky Linux 8.6 필수 패키지 설치 (오프라인 환경 고려)
  sudo $PKG -y install dmidecode || echo "[WARN] dmidecode 설치 실패, 계속 진행"
  
  # RPM 파일 존재 확인
  if [[ ! -f "$ALLOY_RPM_PATH" ]]; then
    echo "[ERROR] Alloy RPM 파일을 찾을 수 없습니다: $ALLOY_RPM_PATH"
    echo "다음 위치에 파일이 있는지 확인하세요:"
    echo "  - $HOME/alloy-1.10.0-1.amd64.rpm"
    exit 1
  fi
  
  echo "[INFO] Alloy RPM 파일 발견: $ALLOY_RPM_PATH"
  
  # 로컬 RPM 설치
  sudo rpm -Uvh "$ALLOY_RPM_PATH" || {
    echo "[ERROR] Alloy RPM 설치 실패"
    echo "RPM 파일 정보:"
    rpm -qpi "$ALLOY_RPM_PATH" 2>/dev/null || echo "RPM 정보 조회 실패"
    exit 1
  }
  
  echo "[INFO] Alloy 오프라인 설치 완료"
fi

# 설치 버전 확인
if command -v alloy >/dev/null 2>&1; then
  echo "[INFO] Installed: $(alloy --version | head -n1)"
else
  echo "[ERROR] Alloy 설치 확인 실패"
  exit 1
fi

###############################################################################
# ─── 메타 정보 & 데이터 디렉터리 ────────────────────────────────────────────
sudo mkdir -p /var/lib/alloy/data
sudo chown -R alloy:alloy /var/lib/alloy

# IDC 환경에서는 AWS IMDS 대신 직접 시스템 정보 수집
# dmidecode 권한 문제 해결을 위한 다중 fallback 방식
INSTANCE_TYPE=$(
  # 1순위: DMI 정보 (권한 불필요)
  cat /sys/class/dmi/id/product_name 2>/dev/null | tr ' ' '_' || \
  # 2순위: dmidecode (sudo 권한 필요)
  sudo dmidecode -s system-product-name 2>/dev/null | tr ' ' '_' || \
  # 3순위: fallback
  echo "ftt-lgtm-physical-server"
)
HOSTNAME=$(hostname --fqdn 2>/dev/null || hostname)
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1 || echo "127.0.0.1")

###############################################################################
# ─── Alloy Config (River) ───────────────────────────────────────────────────
cat <<EOF | sudo tee "$ALLOY_CONFIG_PATH" >/dev/null
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
prometheus.exporter.process "proc" {}

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

otelcol.receiver.otlp "lgtm_tempo_trace" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
  output { traces = [otelcol.processor.batch.default.input] }
}

otelcol.processor.batch "default" {
  send_batch_size     = 1000
  send_batch_max_size = 2000
  timeout             = "2s"
  output { traces = [otelcol.exporter.otlp.tempo_out.input] }
}

otelcol.auth.headers "tempo_tenant" {
  header {
    key   = "X-Scope-OrgID"
    value = "${TENANT_HEADER}"
  }
}

otelcol.exporter.otlp "tempo_out" {
  client {
    endpoint = "${TEMPO_HOST}"
    tls { insecure = true }
    auth = otelcol.auth.headers.tempo_tenant.handler
  }
}

//pyroscope.write "central" {
//  endpoint {
//    url = "${PYROSCOPE_URL}"
//    headers = {
//      "X-Scope-OrgID" = "${TENANT_HEADER}",
//    }
//  }

//  external_labels = {
//    env     = "${TENANT_HEADER}",
//    service = "${HOSTNAME}",
//  }
//}

//discovery.relabel "local_pprof" {
//  targets = [
//    {
//      __address__ = "localhost:6060", //실제 모니터링 대상 서비스 port로 변경
//      __scheme__  = "http",
//    },
//  ]
//}

//pyroscope.scrape "local_pprof" {
//  targets         = discovery.relabel.local_pprof.output
//  scrape_interval = "10s"
//  forward_to      = [pyroscope.write.central.receiver]
//}

EOF

# 설정 파일 검증
if command -v alloy >/dev/null 2>&1; then
  alloy validate "$ALLOY_CONFIG_PATH" || {
    echo "[ERROR] Alloy 설정 파일 검증 실패"
    exit 1
  }
  echo "[INFO] Alloy 설정 파일 검증 완료"
else
  echo "[WARN] Alloy 명령어를 찾을 수 없어 설정 검증을 건너뜁니다"
fi

###############################################################################
# ─── systemd override ────────────────────────────────────────────────────────
sudo mkdir -p /etc/systemd/system/alloy.service.d

cat <<EOF | sudo tee /etc/systemd/system/alloy.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/usr/bin/alloy run \
  --server.http.listen-addr=0.0.0.0:${ALLOY_UI_PORT} \
  --storage.path=/var/lib/alloy/data \
  ${ALLOY_CONFIG_PATH}

SupplementaryGroups=systemd-journal adm
Restart=on-failure
RestartSec=5s
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now alloy

echo -e "\n✅ Alloy + Loki + Mimir + Tempo + Pyroscope 구성 완료 (Rocky Linux 8.6 IDC Offline)"
echo "   System  : ${INSTANCE_TYPE} (${HOSTNAME})"
echo "   Version : Alloy ${ALLOY_VERSION} (오프라인 RPM 설치)"
echo "   UI      : http://${LOCAL_IP}:${ALLOY_UI_PORT}/"
echo "   Metrics : job=${ACCOUNT_ID}-node / ${ACCOUNT_ID}-proc  → Mimir"
echo "   Logs    : syslog → Loki (${LOKI_URL})"
#echo "   Profiles: pprof(6060) → Pyroscope (${PYROSCOPE_URL})"