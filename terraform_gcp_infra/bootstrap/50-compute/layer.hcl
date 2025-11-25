# 50-compute 레이어 설정

locals {
  # 기본값 설정
  zone              = "asia-northeast3-a"
  image_family      = "rocky-linux-10-optimized-gcp"
  image_project     = "rocky-linux-cloud"
  boot_disk_size_gb = 50
  boot_disk_type    = "pd-ssd"
  enable_public_ip  = false
  enable_os_login   = true
  preemptible       = false
  tags              = ["ssh-iap"]

  # 인스턴스 정의 (for_each 방식)
  instances = {
    # Jenkins CI/CD 서버
    "jenkins" = {
      hostname          = "jenkins.delabsgames.gg"
      zone              = "asia-northeast3-a"
      machine_type      = "e2-custom-4-8192"  # 4 vCPU, 8GB RAM
      boot_disk_size_gb = 50
      boot_disk_type    = "pd-ssd"
      enable_public_ip  = true
      tags              = ["jenkins", "ssh-iap", "http-server"]
      labels = {
        role    = "ci-cd"
        purpose = "jenkins"
      }
    }

    # Bastion Host (점프 서버)
    "bastion" = {
      hostname          = "bastion.delabsgames.gg"
      zone              = "asia-northeast3-a"
      machine_type      = "e2-small"  # 2 vCPU, 2GB RAM
      boot_disk_size_gb = 20
      boot_disk_type    = "pd-balanced"
      enable_public_ip  = true
      tags              = ["bastion", "ssh-iap"]
      labels = {
        role    = "bastion"
        purpose = "jump-server"
      }
    }
  }
}
