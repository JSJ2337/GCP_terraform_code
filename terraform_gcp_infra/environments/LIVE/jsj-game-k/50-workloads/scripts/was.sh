#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y docker.io google-fluentd
systemctl enable docker
systemctl start docker
systemctl enable google-fluentd
systemctl start google-fluentd
