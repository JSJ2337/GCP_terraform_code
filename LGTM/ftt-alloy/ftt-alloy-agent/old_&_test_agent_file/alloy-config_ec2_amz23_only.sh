#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh 
###############################################################################
JOB_NAME="aws-rag"
MIMIR_URL="http://10.23.50.147:9009/api/v1/push"
TENANT_HEADER="aws-rag-ec2"
LOKI_URL="http://10.23.50.147:3100/loki/api/v1/push"
LOKI_TENANT="aws-rag-ec2"
TEMPO_HOST="10.23.50.147"
ALLOY_UI_PORT="12345"
ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"
ALLOY_VERSION="latest"
CONFIG_TEMPLATE_PATH="./config.alloy"
###############################################################################
# 
# 
if ! getent group alloy >/dev/null; then
  sudo groupadd --system alloy
fi

# 
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

echo "[INFO] Alloy 

###################### CONFIG #################################################
sed -e "s|__INSTANCE_ID__|${INSTANCE_ID}|g" \
    -e "s|__INSTANCE_TYPE__|${INSTANCE_TYPE}|g" \
    -e "s|__HOSTNAME__|${HOSTNAME}|g" \
    -e "s|__ACCOUNT_ID__|${JOB_NAME}|g" \
    -e "s|__LOKI_URL__|${LOKI_URL}|g" \
    -e "s|__LOKI_TENANT__|${LOKI_TENANT}|g" \
    -e "s|__NODE_JOB_NAME__|${JOB_NAME}_node|g" \
    -e "s|__PROC_JOB_NAME__|${JOB_NAME}_proc|g" \
    -e "s|__MIMIR_URL__|${MIMIR_URL}|g" \
    -e "s|__TENANT_HEADER__|${TENANT_HEADER}|g" \
    -e "s|__TEMPO_HOST__|${TEMPO_HOST}|g" \
    "${CONFIG_TEMPLATE_PATH}" | sudo tee "${ALLOY_CONFIG_PATH}" >/dev/null

/usr/bin/alloy validate "$ALLOY_CONFIG_PATH" || { echo "[ERROR] Alloy config "; exit 1; }

###################### SYSTEMD ################################################
sudo mkdir -p /etc/systemd/system/alloy.service.d /var/lib/alloy
sudo chown alloy:alloy /var/lib/alloy

cat <<EOF | sudo tee /etc/systemd/system/alloy.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/usr/bin/alloy run \
  --server.http.listen-addr=0.0.0.0:${ALLOY_UI_PORT} \
  --storage.path=/var/lib/alloy/data \
  ${ALLOY_CONFIG_PATH}

EnvironmentFile=/var/lib/alloy/meta.env
ExecStartPre=/usr/bin/bash -c 'IT="unknown"; INSTANCE_TYPE_RAW=$(curl -s http://169.254.169.254/latest/meta-data/instance-type); if [ -n "$INSTANCE_TYPE_RAW" ]; then IT="$INSTANCE_TYPE_RAW"; fi; echo "INSTANCE_TYPE=$IT" > /var/lib/alloy/meta.env'

Restart=on-failure
RestartSec=5s
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now alloy

for i in {1..30}; do
  if systemctl is-active --quiet alloy; then
    echo "[INFO] alloy 
    break
  }
  sleep 1
  if [[ $i -eq 30 ]]; then
    echo "[ERROR] alloy 
    exit 1
  }
done

rm -f /tmp/aws-otel-collector.rpm /tmp/node_exporter.tgz 2>/dev/null || true

cat <<MSG

 - UI:      http://${LOCAL_IP}:${ALLOY_UI_PORT}/
 - 
 - 
MSG