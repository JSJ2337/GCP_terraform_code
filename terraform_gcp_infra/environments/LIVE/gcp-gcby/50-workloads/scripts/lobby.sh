#!/usr/bin/env bash
set -euo pipefail

# Rocky Linux 10 startup script for lobby instances

# SSH 비밀번호 인증 활성화
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# sshd_config.d 디렉토리 파일도 수정 (Rocky Linux)
if [ -d /etc/ssh/sshd_config.d ]; then
  for f in /etc/ssh/sshd_config.d/*.conf; do
    [ -f "$f" ] && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$f"
  done
fi

# SSH 서비스 재시작
systemctl restart sshd

# 기본 사용자 생성 및 비밀번호 설정
# 사용자명: delabs-adm, 비밀번호: 초기 배포 후 반드시 변경 필요!
if ! id "delabs-adm" &>/dev/null; then
  useradd -m -s /bin/bash -G wheel delabs-adm
  echo "delabs-adm:REDACTED_PASSWORD" | chpasswd
fi

# sudo 비밀번호 없이 사용 가능하도록 설정
echo "delabs-adm ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/delabs-adm
chmod 440 /etc/sudoers.d/delabs-adm

echo "SSH password authentication enabled"

# Update system packages
dnf update -y

# Install basic utilities
dnf install -y curl wget vim net-tools

echo "Lobby instance initialization complete"
