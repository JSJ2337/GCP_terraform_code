#!/usr/bin/env bash
# Rocky Linux 10 startup script for lobby instances
# Note: set -e 제거 - 메타데이터 조회 실패 시에도 계속 진행하도록

set -uo pipefail

# GCE 메타데이터에서 Admin 사용자 정보 가져오기
METADATA_URL="http://metadata.google.internal/computeMetadata/v1"

# admin-username 가져오기 (실패 시 기본값 사용)
ADMIN_USER=$(curl -sf -H "Metadata-Flavor: Google" "${METADATA_URL}/instance/attributes/admin-username" 2>/dev/null) || ADMIN_USER="admin"

# admin-password 가져오기 (실패 시 빈 값)
ADMIN_PASSWORD=$(curl -sf -H "Metadata-Flavor: Google" "${METADATA_URL}/instance/attributes/admin-password" 2>/dev/null) || ADMIN_PASSWORD=""

echo "Starting startup script with user: ${ADMIN_USER}"

# SSH 비밀번호 인증 활성화
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# UsePAM yes 설정 (Rocky Linux 10에서 PAM 인증 필수)
sed -i 's/^#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

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
dnf install -y curl wget vim net-tools nmap-ncat bind-utils

echo "Lobby instance initialization complete"
