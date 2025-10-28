#!/usr/bin/env bash
set -euo pipefail


### ── 사용자 설정 ─────────────────────────────────────────────
JOB_NAME="aws-rag"
MIMIR_URL="http://10.23.50.147:9009/api/v1/push"
TENANT_HEADER="anonymous"
AWS_REGION="ap-southeast-1"
ADOT_VER="latest"         # "latest" 또는 "v0.43.3"
NODE_EXPORTER_VER="latest" # "latest" 또는 특정 버전(예: "1.7.1")
### ───────────────────────────────────────────────────────────────

### ── 자동 IP 검출 ────────────────────────────────────────────
# hostname -i 에서 IPv4만 뽑아오기
LOCAL_IP=$(hostname -i | tr ' ' '\n' \
           | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
           | head -n1)
echo "Detected IPv4: $LOCAL_IP"
### ───────────────────────────────────────────────────────────────

# 1) 아키텍처 결정
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) ARCH=arm64 ;;
  x86_64)  ARCH=amd64 ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

### ── ADOT Collector 설치/업데이트 ─────────────────────────────
# RPM URL 결정
if [[ "$ADOT_VER" == "latest" ]]; then
  RPM_URL="https://aws-otel-collector.s3.amazonaws.com/amazon_linux/${ARCH}/latest/aws-otel-collector.rpm"
else
  VER_NO="${ADOT_VER#v}"
  RPM_URL="https://aws-otel-collector.s3.amazonaws.com/amazon_linux/${ARCH}/${VER_NO}/aws-otel-collector.rpm"
fi

echo "→ Downloading ADOT Collector RPM: $RPM_URL"
curl -sSL "$RPM_URL" -o /tmp/aws-otel-collector.rpm

echo "→ Importing GPG & Installing RPM"
sudo rpm --import https://aws-otel-collector.s3.amazonaws.com/aws-otel-collector.gpg
sudo rpm -Uvh /tmp/aws-otel-collector.rpm

# config 디렉터리 보장
sudo mkdir -p /opt/aws/aws-otel-collector/etc

# 새 config.yaml 생성/덮어쓰기
echo "→ Writing config to /opt/aws/aws-otel-collector/etc/config.yaml"
sudo tee /opt/aws/aws-otel-collector/etc/config.yaml > /dev/null <<EOF
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: "${JOB_NAME}"
          static_configs:
            - targets: ["${LOCAL_IP}:9100"]

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 256
  batch:
    send_batch_size: 2000
    timeout: 10s

exporters:
  prometheusremotewrite:
    endpoint: "${MIMIR_URL}"
    headers:
      X-Scope-OrgID: "${TENANT_HEADER}"
    timeout: 10s
    retry_on_failure:
      enabled: true

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
EOF

# Collector 재시작: -c 옵션을 -a 옵션 앞에!
echo "→ Restarting ADOT Collector service"
sudo /opt/aws/aws-otel-collector/bin/aws-otel-collector-ctl -a stop || true
sudo /opt/aws/aws-otel-collector/bin/aws-otel-collector-ctl \
  -c /opt/aws/aws-otel-collector/etc/config.yaml -a start

### ── Node Exporter 설치 ───────────────────────────────────────
echo "→ Installing Node Exporter (${NODE_EXPORTER_VER})"

# 버전별 URL 가져오기
if [[ "$NODE_EXPORTER_VER" == "latest" ]]; then
  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest \
    | grep browser_download_url | grep "linux-${ARCH}.tar.gz" | cut -d '"' -f 4)
else
  DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VER}/node_exporter-${NODE_EXPORTER_VER}.linux-${ARCH}.tar.gz"
fi

echo "→ Downloading from $DOWNLOAD_URL"
curl -sSL "$DOWNLOAD_URL" -o /tmp/node_exporter.tgz
tar -xzf /tmp/node_exporter.tgz -C /tmp

echo "→ Installing binary to /usr/local/bin"
sudo mv /tmp/node_exporter-*/node_exporter /usr/local/bin/

# 서비스 유저 및 systemd 서비스 파일
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# systemd 재시작/활성화
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

echo -e "\n🎉 ADOT Collector & Node Exporter 설치/구성 완료! 🎉"
