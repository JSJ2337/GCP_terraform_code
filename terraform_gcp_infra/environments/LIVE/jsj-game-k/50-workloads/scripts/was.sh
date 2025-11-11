#!/bin/bash
apt-get update
apt-get install -y docker.io google-fluentd
systemctl enable docker && systemctl start docker
systemctl enable google-fluentd && systemctl start google-fluentd
