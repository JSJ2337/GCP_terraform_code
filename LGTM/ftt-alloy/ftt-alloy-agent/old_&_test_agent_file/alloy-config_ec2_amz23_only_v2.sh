#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh — Amazon Linux(2 / 2023) + Loki 연동
###############################################################################
JOB_NAME="aws-rag"
MIMIR_URL="http://10.23.50.147:9009/api/v1/push"
TENANT_HEADER="aws-rag-ec2"
LOKI_URL="http://10.23.50.147:3100/loki/api/v1/push"
LOKI_TENANT="aws-rag-ec2"
TEMPO_HOST="10.23.50.147"
ALLOY_UI_PORT="12345"
ALLOY_RIVER_PATH="/etc/alloy/alloy.river"
ALLOY_VERSION="latest"
###############################################################################
# ─── Alloy 전용 시스템 계정/그룹 미리 생성 (로그인 불가) ───
# 그룹이 없으면 생성
if ! getent group alloy >/dev/null; then
  sudo groupadd --system alloy
fi

# 사용자가 없으면 생성
if ! id -u alloy >/dev/null 2>&1; then
  sudo useradd \
    --system \
    --no-create-home \
    --shell /sbin/nologin \
    --gid alloy \
    alloy
fi
if rpm -q alloy &>/dev/null; then
  INSTALL_ALLOY=false
else
  INSTALL_ALLOY=true
fi

LOCAL_IP=$(hostname -i | awk '{print $1}')
IMDS_TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
MD_HEADER=(); [[ -n "$IMDS_TOKEN" ]] && MD_HEADER=(-H "X-aws-ec2-metadata-token: $IMDS_TOKEN")
INSTANCE_ID=$(curl -s "http://169.254.169.254/latest/meta-data/instance-id" "${MD_HEADER[@]}" || echo unknown)
INSTANCE_TYPE=$(curl -s "http://169.254.169.254/latest/meta-data/instance-type" "${MD_HEADER[@]}" || echo unknown)
HOSTNAME="$(hostname --fqdn)" 
sudo mkdir -p /var/lib/alloy
echo "INSTANCE_TYPE=$INSTANCE_TYPE" | sudo tee /var/lib/alloy/meta.env >/dev/null
sudo chown alloy:alloy /var/lib/alloy/meta.env

ARCH=$(uname -m); [[ "$ARCH" == "aarch64" ]] && ARCH=arm64 || ARCH=amd64
PKG=$(grep -q "Amazon Linux release 2023" /etc/os-release && echo dnf || echo yum)

if [[ "$INSTALL_ALLOY" == true ]]; then
  sudo mkdir -p /etc/yum.repos.d
  sudo curl -sSL https://rpm.grafana.com/gpg.key -o /etc/pki/rpm-grafana-gpg.key
  sudo rpm --import /etc/pki/rpm-grafana-gpg.key
  cat <<'REPO' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
enabled=1
repo_gpgcheck=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
REPO
  sudo $PKG -y update
  if [[ "$ALLOY_VERSION" == "latest" ]]; then
    sudo $PKG -y install alloy
  else
    sudo $PKG -y install "alloy-$ALLOY_VERSION" || sudo $PKG -y install alloy
  fi
  sudo $PKG clean all
fi

echo "[INFO] Alloy 버전 → $(/usr/bin/alloy --version | head -n1)"

###################### RIVER ##################################################
cat <<EOF | sudo tee "$ALLOY_RIVER_PATH" >/dev/null
// 로그 레벨 및 포맷 설정
logging {
  level  = "info"
  format = "logfmt"
}

// 프로메테우스 메트릭 Exporter (노드/프로세스)
prometheus.exporter.unix    "node" {}
prometheus.exporter.process "proc" {}

// journald 로그를 Loki로 전송 (syslog)
loki.source.journal "journald" {
  labels     = { job = "syslog" }
  forward_to = [loki.process.enrich.receiver]
}

loki.process "enrich" {
  stage.static_labels {
    values = {
      instance_id   = "${INSTANCE_ID}",
      instance_type = "${INSTANCE_TYPE}",
      hostname      = "${HOSTNAME}",
      account_id    = "${JOB_NAME}",
      job           = "syslog",
    }
  }
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url       = "${LOKI_URL}"
    tenant_id = "${LOKI_TENANT}"
  }
}

// 메트릭 레이블 추가 (노드, 프로세스)
discovery.relabel "node_lbl" {
  targets = prometheus.exporter.unix.node.targets

  rule {
    action       = "replace"
    target_label = "instance_id"
    replacement  = "${INSTANCE_ID}"
  }
  rule {
    action       = "replace"
    target_label = "instance_type"
    replacement  = "${INSTANCE_TYPE}"
  }
  rule {
    action       = "replace"
    target_label = "job"
    replacement  = "${JOB_NAME}_node"
  }
}

discovery.relabel "proc_lbl" {
  targets = prometheus.exporter.process.proc.targets

  rule {
    action       = "replace"
    target_label = "instance_id"
    replacement  = "${INSTANCE_ID}"
  }
  rule {
    action       = "replace"
    target_label = "instance_type"
    replacement  = "${INSTANCE_TYPE}"
  }
  rule {
    action       = "replace"
    target_label = "job"
    replacement  = "${JOB_NAME}_proc"
  }
}

// 프로메테우스 메트릭 스크랩 및 Mimir로 전송
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

// 프로메테우스 메트릭 Mimir로 Remote Write
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

// tempo 연결 설정
otelcol.receiver.otlp "ftt_tempo_trace" {
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
    value = "${TENANT_HEADER}_tempo"
  }
}

otelcol.exporter.otlp "tempo_out" {
  client {
    endpoint = "${TEMPO_HOST}:4317"
    tls { insecure = true }
    auth = otelcol.auth.headers.tempo_tenant.handler
  }
}


EOF

/usr/bin/alloy validate "$ALLOY_RIVER_PATH" || { echo "[ERROR] River 검증 실패"; exit 1; }

###################### SYSTEMD ################################################
sudo mkdir -p /etc/systemd/system/alloy.service.d /var/lib/alloy
sudo chown alloy:alloy /var/lib/alloy

cat <<EOF | sudo tee /etc/systemd/system/alloy.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/usr/bin/alloy run \
  --server.http.listen-addr=0.0.0.0:${ALLOY_UI_PORT} \
  --storage.path=/var/lib/alloy/data \
  ${ALLOY_RIVER_PATH}

EnvironmentFile=/var/lib/alloy/meta.env
ExecStartPre=/usr/bin/bash -c 'IT=\$(curl -s http://169.254.169.254/latest/meta-data/instance-type || echo unknown); echo "INSTANCE_TYPE=\$IT" > /var/lib/alloy/meta.env'

Restart=on-failure
RestartSec=5s
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now alloy

for i in {1..30}; do
  if systemctl is-active --quiet alloy; then
    echo "[INFO] alloy 서비스가 활성화됨"
    break
  fi
  sleep 1
  if [[ $i -eq 30 ]]; then
    echo "[ERROR] alloy 서비스 기동 확인 실패"
    exit 1
  fi
done

rm -f /tmp/aws-otel-collector.rpm /tmp/node_exporter.tgz 2>/dev/null || true

cat <<MSG
✅ Alloy + Loki 구성 완료
 - UI:      http://${LOCAL_IP}:${ALLOY_UI_PORT}/
 - 메트릭:  job=${JOB_NAME}_node / ${JOB_NAME}_proc  → Mimir
 - 로그:    syslog → Loki (${LOKI_URL})
MSG
