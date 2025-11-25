# 50-compute 레이어 설정

locals {
  # 기본값 설정
  zone              = "asia-northeast3-a"
  image_family      = "rocky-linux-10-optimized-gcp"
  image_project     = "rocky-linux-cloud"
  boot_disk_size_gb = 100
  boot_disk_type    = "pd-ssd"
  enable_public_ip  = false
  enable_os_login   = true
  preemptible       = false
  tags              = ["ssh-iap"]

  # SSH 비밀번호 접속 활성화 스크립트
  ssh_password_script = <<-EOT
#!/bin/bash
set -e

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

echo "SSH password authentication enabled"
EOT

  # 인스턴스 정의 (for_each 방식)
  instances = {
    # Jenkins CI/CD 서버
    "delabs-terraform-jenkins" = {
      hostname            = "delabs-terraform-jenkins.delabsgames.gg"
      zone                = "asia-northeast3-a"
      machine_type        = "e2-custom-4-8192"  # 4 vCPU, 8GB RAM
      boot_disk_size_gb   = 100
      boot_disk_type      = "pd-ssd"
      enable_public_ip    = true
      create_static_ip    = true  # 고정 IP 사용
      deletion_protection = false # 삭제 방지 비활성화
      tags                = ["jenkins", "ssh-iap", "http-server"]
      labels = {
        role    = "ci-cd"
        purpose = "jenkins"
      }
      startup_script = local.ssh_password_script
    }

    # Bastion Host (점프 서버)
    "delabs-bastion" = {
      hostname            = "delabs-bastion.delabsgames.gg"
      zone                = "asia-northeast3-a"
      machine_type        = "e2-small"  # 2 vCPU, 2GB RAM
      boot_disk_size_gb   = 100
      boot_disk_type      = "pd-ssd"
      enable_public_ip    = true
      create_static_ip    = true  # 고정 IP 사용
      deletion_protection = false # 삭제 방지 비활성화
      tags                = ["bastion", "ssh-iap"]
      labels = {
        role    = "bastion"
        purpose = "jump-server"
      }
      startup_script = local.ssh_password_script
    }
  }
}
