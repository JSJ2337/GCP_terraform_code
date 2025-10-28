#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# install_alloy.sh - Amazon Linux 2 or 2023 (with Pyroscope profiling push)
###############################################################################
JOB_NAME="aws-rag"

MIMIR_URL="http://10.23.50.147:9009/api/v1/push"
TENANT_HEADER="aws-rag-ec2"

LOKI_URL="http://10.23.50.147:3100/loki/api/v1/push"
LOKI_TENANT="aws-rag-ec2"

TEMPO_HOST="10.23.50.147"

# ──────── NEW: Pyroscope endpoint ───────────────────────────────────────────
PYROSCOPE_URL="http://10.23.50.147:4040"
# ─────────────────────────────────────────────────────────────────────────────

ALLOY_UI_PORT="12345"
ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"
ALLOY_VERSION="1.9.2"               # 안정 버전

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

PKG=$(grep -q "Amazon Linux release 2023" /etc/os-release && echo dnf || echo yum)

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

IMDS_TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
MD_HEADER=(); [[ -n "$IMDS_TOKEN" ]] && MD_HEADER=(-H "X-aws-ec2-metadata-token: $IMDS_TOKEN")
INSTANCE_TYPE=$(curl -s "http://169.254.169.254/latest/meta-data/instance-type" "${MD_HEADER[@]}" || echo unknown)
HOSTNAME=$(hostname --fqdn)
LOCAL_IP=$(hostname -i | awk '{print $1}')

###############################################################################
# ─── Alloy Config (River) ───────────────────────────────────────────────────
cat <<EOF | sudo tee "$ALLOY_CONFIG_PATH" >/dev/null
logging {
  level  = "info"
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
      account_id    = "${JOB_NAME}",
      job           = "syslog",
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

//pyroscope.write "central" {
//  endpoint {
//    url = "${PYROSCOPE_URL}"
//    headers = {
//      "X-Scope-OrgID" = "${TENANT_HEADER}_profile",
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

echo -e "\n✅ Alloy + Loki + Mimir + Tempo + Pyroscope 구성 완료"
echo "   UI      : http://${LOCAL_IP}:${ALLOY_UI_PORT}/"
echo "   Metrics : job=${JOB_NAME}_node / ${JOB_NAME}_proc  → Mimir"
echo "   Logs    : syslog → Loki (${LOKI_URL})"
#echo "   Profiles: pprof(6060) → Pyroscope (${PYROSCOPE_URL})"
