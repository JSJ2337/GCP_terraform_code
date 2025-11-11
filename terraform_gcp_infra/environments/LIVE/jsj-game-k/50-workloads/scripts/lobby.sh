#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y nginx google-fluentd
systemctl enable nginx
systemctl start nginx
systemctl enable google-fluentd
systemctl start google-fluentd
