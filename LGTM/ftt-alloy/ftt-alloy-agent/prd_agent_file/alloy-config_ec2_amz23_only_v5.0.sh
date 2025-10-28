#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh - Unified LGTM Stack Configuration
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

# OS 감지 및 패키지 매니저 선택
if grep -q "Amazon Linux release 2023" /etc/os-release 2>/dev/null; then
  PKG="dnf"
  OS_TYPE="amz23"
elif grep -q "Amazon Linux release 2" /etc/os-release 2>/dev/null; then
  PKG="yum"
  OS_TYPE="amz2"
elif grep -q "Rocky Linux" /etc/os-release 2>/dev/null; then
  PKG="dnf"
  OS_TYPE="rocky"
else
  PKG="yum"
  OS_TYPE="unknown"
fi

if $INSTALL_ALLOY; then
  sudo mkdir -p /etc/yum.repos.d
  sudo curl -sSL https://rpm.grafana.com/gpg.key -o /etc/pki/rpm-grafana-gpg.key
  sudo rpm --import /etc/pki/rpm-grafana-gpg.key

  cat <<'REPO' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
enabled=1
repo_gpgcheck=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
REPO

  sudo $PKG -y update
  sudo $PKG -y install "alloy-${ALLOY_VERSION}" || sudo $PKG -y install alloy
  sudo $PKG clean all
fi

echo "[INFO] Installed: $(/usr/bin/alloy --version | head -n1)"

###############################################################################
# ─── 메타 정보 & 데이터 디렉터리 ────────────────────────────────────────────
sudo mkdir -p /var/lib/alloy/data
sudo chown -R alloy:alloy /var/lib/alloy

# 환경별 메타데이터 수집
if [[ "$OS_TYPE" == "amz"* ]]; then
  # AWS EC2 메타데이터
  IMDS_TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
  MD_HEADER=(); [[ -n "$IMDS_TOKEN" ]] && MD_HEADER=(-H "X-aws-ec2-metadata-token: $IMDS_TOKEN")
  INSTANCE_TYPE=$(curl -s "http://169.254.169.254/latest/meta-data/instance-type" "${MD_HEADER[@]}" || echo "unknown")
else
  # IDC/온프레미스 환경
  INSTANCE_TYPE=$(
    cat /sys/class/dmi/id/product_name 2>/dev/null | tr ' ' '_' || \
    sudo dmidecode -s system-product-name 2>/dev/null | tr ' ' '_' || \
    echo "ftt-lgtm-physical-server"  # 통일된 fallback 값
  )
fi

HOSTNAME=$(hostname --fqdn 2>/dev/null || hostname)
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1 || echo "127.0.0.1")

###############################################################################
# ─── Alloy Config (River) ───────────────────────────────────────────────────
cat <<EOF | sudo tee "$ALLOY_CONFIG_PATH" >/dev/null
logging {
  level  = "warn"
  format = "logfmt"
}

loki.source.journal "journald" {
  labels = {
    job = "syslog",
  }
  forward_to = [loki.process.enrich.receiver]
}

loki.process "enrich" {
  forward_to = [loki.write.default.receiver]

  stage.match {
    selector = "{_PRIORITY=~\"^(7|5)\"}" // Drop debug and notice logs
    action   = "drop"
  }

  stage.static_labels {
    values = {
      instance_type = "${INSTANCE_TYPE}",
      hostname      = "${HOSTNAME}",
      account_id    = "${ACCOUNT_ID}",
      job           = "${JOB_NAME}",
    }
  }

  stage.labels {
    values = {
      level = "_PRIORITY",
    }
  }
}

loki.write "default" {
  endpoint {
    url       = "${LOKI_URL}"
    tenant_id = "${LOKI_TENANT}"
  }
}

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
    replacement  = "${ACCOUNT_ID}-node"
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
    replacement  = "${ACCOUNT_ID}-proc"
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

/usr/bin/alloy validate "$ALLOY_CONFIG_PATH"

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

echo -e "\n✅ Alloy + LGTM Stack 구성 완료"
echo "   System  : ${INSTANCE_TYPE} (${HOSTNAME})"
echo "   UI      : http://${LOCAL_IP}:${ALLOY_UI_PORT}/"
echo "   Metrics : job=${ACCOUNT_ID}-node / ${ACCOUNT_ID}-proc  → Mimir"
echo "   Logs    : syslog → Loki (${LOKI_URL})"
#echo "   Profiles: pprof(6060) → Pyroscope (${PYROSCOPE_URL})"