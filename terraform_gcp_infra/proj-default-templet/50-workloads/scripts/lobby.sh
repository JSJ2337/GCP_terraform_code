#!/bin/bash
apt-get update
apt-get install -y nginx google-fluentd
systemctl enable nginx && systemctl start nginx
systemctl enable google-fluentd && systemctl start google-fluentd
