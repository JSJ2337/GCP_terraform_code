#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh  (AL2023 + Alloy 1.9.2 + Loki 3.5 + Mimir 2.16 + Tempo 2.8)
###############################################################################
JOB_NAME="aws-rag"

MIMIR_URL="http://10.23.50.147:9009/api/v1/push"
TENANT_HEADER="aws-rag-ec2"

LOKI_URL="http://10.23.50.147:3100/loki/api/v1/push"
LOKI_TENANT="aws-rag-ec2"

TEMPO_HOST="10.23.50.147"

ALLOY_VERSION="1.9.2"
ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"

###############################################################################
# 1) alloy 계정 + journald 읽기 권한
###############################################################################
getent group alloy        >/dev/null || sudo groupadd --system alloy
id -u alloy >/dev/null 2>&1 || sudo useradd --system --no-create-home \
                                      --shell /sbin/nologin --gid alloy alloy

for g in systemd-journal adm; do
  getent group "$g" >/dev/null || sudo groupadd --system "$g"
done
sudo usermod -aG systemd-journal,adm alloy

###############################################################################
# 2) Alloy RPM 설치(없으면)
###############################################################################
if ! rpm -q alloy &>/dev/null; then
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

  sudo dnf -y update
  sudo dnf -y install "alloy-${ALLOY_VERSION}" || sudo dnf -y install alloy
  sudo dnf clean all
fi

###############################################################################
# 3) 데이터·메타 디렉터리
###############################################################################
sudo mkdir -p /var/lib/alloy/data
sudo chown -R alloy:alloy /var/lib/alloy

INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type || echo unknown)
echo "INSTANCE_TYPE=${INSTANCE_TYPE}" | sudo tee /var/lib/alloy/meta.env >/dev/null
sudo chown alloy:alloy /var/lib/alloy/meta.env

LOCAL_IP=$(hostname -i | awk '{print $1}')
HOSTNAME=$(hostname --fqdn)

###############################################################################
# 4) River 구성 (쉼표·inline 주석 없음)
###############################################################################
sudo tee "${ALLOY_CONFIG_PATH}" >/dev/null <<EOF
logging {
  level  = "info"
  format = "logfmt"
}

loki.source.journal "journald" {
  path = "/run/log/journal"

  labels = {
    job = "syslog"
  }

  forward_to = [loki.process.enrich.receiver]
}

loki.process "enrich" {
  stage.match {
    selector = "{_PRIORITY=~\"^(7|5)\"}"
    action   = "drop"
  }

  stage.labels {
    values = {
      level         = "{{ ._PRIORITY }}",
      instance_type = "${INSTANCE_TYPE}",
      hostname      = "${HOSTNAME}",
      account_id    = "${JOB_NAME}",
      job           = "syslog"
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
    replacement  = "${JOB_NAME}_node"
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
    replacement  = "${JOB_NAME}_proc"
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

otelcol.receiver.otlp "tempo_in" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }

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

###############################################################################
# 5) 검증·서비스 재시작
###############################################################################
sudo /usr/bin/alloy validate "${ALLOY_CONFIG_PATH}"
sudo systemctl daemon-reload
sudo systemctl restart alloy
sudo systemctl enable  alloy

echo
echo "✅  Alloy + Loki + Mimir + Tempo 배포 완료"
echo "    Grafana Explore → {job=\"syslog\"} 로 로그 유입 확인"
echo "    Alloy UI       → http://${LOCAL_IP}:12345/"
