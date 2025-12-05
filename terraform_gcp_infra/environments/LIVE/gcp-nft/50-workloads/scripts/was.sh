#!/usr/bin/env bash
set -euo pipefail

# Rocky Linux 10 startup script for WAS instances

# GCE 메타데이터에서 Admin 사용자 정보 가져오기
METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
ADMIN_USER=$(curl -s -H "Metadata-Flavor: Google" "${METADATA_URL}/instance/attributes/admin-username" 2>/dev/null || echo "admin")
ADMIN_PASSWORD=$(curl -s -H "Metadata-Flavor: Google" "${METADATA_URL}/instance/attributes/admin-password" 2>/dev/null || echo "")

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
# 사용자명: 메타데이터에서 가져옴, 비밀번호: 초기 배포 후 반드시 변경 필요!
if ! id "${ADMIN_USER}" &>/dev/null; then
  useradd -m -s /bin/bash -G wheel "${ADMIN_USER}"
  if [ -n "${ADMIN_PASSWORD}" ]; then
    echo "${ADMIN_USER}:${ADMIN_PASSWORD}" | chpasswd
  fi
fi

# sudo 비밀번호 없이 사용 가능하도록 설정
echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${ADMIN_USER}
chmod 440 /etc/sudoers.d/${ADMIN_USER}

echo "SSH password authentication enabled for user: ${ADMIN_USER}"

# Update system packages
dnf update -y

# Install basic utilities
dnf install -y curl wget vim net-tools

echo "WAS instance initialization complete"
