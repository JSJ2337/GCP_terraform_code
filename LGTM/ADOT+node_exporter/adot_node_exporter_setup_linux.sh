#!/usr/bin/env bash
# adot-node-exporter-install.sh ────────────────────────────────────────────
# Amazon Linux 2023 ▸ AWS Distro for OpenTelemetry Collector + Node Exporter
# • 최신 RPM 자동 설치  • Grafana Mimir 원격 write 구성
# • Node Exporter 설치 및 systemd 서비스 구성
# • systemd 유닛 오버라이드로 ADOT 즉시 기동

set -euo pipefail

### ─── 1. 사용자 값만 수정 ───────────────────────────────────────────────
MIMIR_URL="http://10.23.50.147:9009/api/v1/push"   # ← Mimir remote-write
TENANT_HEADER="anonymous"                    # ← 빈 값이면 헤더 미전송
AWS_REGION="ap-northeast-2"                        # ← Collector 내부에서 사용
ADOT_VER="latest"                                  # "latest" 또는 "v0.43.3" 등
NODE_EXPORTER_VER="1.7.2"                          # 설치할 node-exporter 버전
JOB_NAME="aws-rag"                                 # 서비스 명
### ────────────────────────────────────────────────────────────────────

### ─── a) Node Exporter 설치 & 서비스 설정 ────────────────────────────
echo ">>> A) Node Exporter 설치 및 시스템 서비스 구성"
# 1) 다운로드
curl -fsSL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VER}/node_exporter-${NODE_EXPORTER_VER}.linux-amd64.tar.gz" \
 -o /tmp/node_exporter.tar.gz
tar zxvf /tmp/node_exporter.tar.gz -C /tmp
# 2) 바이너리 복사
install -m 755 /tmp/node_exporter-${NODE_EXPORTER_VER}.linux-amd64/node_exporter /usr/local/bin/node_exporter
# 3) systemd 서비스 파일 작성
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
# 4) 서비스 등록 및 시작
systemctl daemon-reload
systemctl enable --now node_exporter

### ─── 0) 아키텍처 결정 및 RPM URL 생성 ─────────────────────────────────
echo ">>> 0) ADOT 아키텍처 결정 및 RPM URL 생성"
case $(uname -m) in
  aarch64) ARCH=arm64 ;;
  x86_64)  ARCH=amd64 ;;
  *) echo "❌ Unsupported arch: $(uname -m)"; exit 1 ;;
esac
RPM_URL="https://aws-otel-collector.s3.amazonaws.com/amazon_linux/${ARCH}/${ADOT_VER}/aws-otel-collector.rpm"
ROOT="/opt/aws/aws-otel-collector"
CFG="${ROOT}/etc/config.yaml"
ENV="${ROOT}/etc/.env"
OVR="/etc/systemd/system/aws-otel-collector.service.d/override.conf"

### ─── 1) ADOT RPM 다운로드 및 설치 ────────────────────────────────────
echo ">>> 1) ADOT Collector RPM 다운로드 및 설치"
curl -fsSL "$RPM_URL" -o /tmp/aws-otel-collector.rpm
rpm -q aws-otel-collector && rpm -e aws-otel-collector || true
rpm -Uvh /tmp/aws-otel-collector.rpm

### ─── 2) Collector YAML 작성 ─────────────────────────────────────────
echo ">>> 2) Collector YAML 작성"
install -d "$(dirname "$CFG")"
cat > "$CFG" <<EOF
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: "${JOB_NAME}"
          static_configs:
            - targets: ["127.0.0.1:9100"]

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
    endpoint: "${MIMIR_URL}"$( [ -n "$TENANT_HEADER" ] && \
      printf "\n    headers: { X-Scope-OrgID: \"%s\" }" "$TENANT_HEADER" )
    timeout: 30s
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

service:
  telemetry:
    metrics:
      address: "0.0.0.0:8888"
  pipelines:
    metrics:
      receivers:  [prometheus]
      processors: [batch]
      exporters:  [prometheusremotewrite]
EOF

### ─── 3) .env 작성 (--config 플래그 전달) ──────────────────────────────
echo ">>> 3) .env 작성 (ec2-user 권한)"
install -d "$(dirname "$ENV")"
cat > "$ENV" <<EOF
config="--config ${CFG}"
AWS_REGION=${AWS_REGION}
EOF
chown ec2-user:ec2-user "$ENV"
chmod 640 "$ENV"

### ─── 4) systemd 유닛 오버라이드: $config 제거, ExecStart 직접 지정 ───────
echo ">>> 4) systemd 유닛 오버라이드 설정"
install -d "$(dirname "$OVR")"
cat > "$OVR" <<EOF
[Service]
EnvironmentFile=$ENV
ExecStart=
ExecStart=${ROOT}/bin/aws-otel-collector --config ${CFG}
EOF
systemctl daemon-reload

### ─── 5) Collector 서비스 Enable + Start ──────────────────────────────
echo ">>> 5) Collector 서비스 활성화 및 시작"
systemctl enable --now aws-otel-collector

### ─── 6) 최종 상태 확인 ───────────────────────────────────────────────
echo ">>> 6) 최종 상태 확인"
systemctl --no-pager -l status node_exporter aws-otel-collector
