# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# VM configuration (for_each map 사용)
instance_count    = 0
machine_type      = "custom-4-8192"  # 4 vCPUs, 8GB RAM
image_family      = "rocky-linux-10-optimized-gcp"
image_project     = "rocky-linux-cloud"
boot_disk_size_gb = 128
boot_disk_type    = "pd-ssd"
enable_public_ip  = false
enable_os_login   = true
preemptible       = false
startup_script    = ""
tags              = ["game", "ssh-allowed"]
labels = {
  environment = "live"
  component   = "game-server"
}

# 역할별 인스턴스 정의
# subnet_type: "dmz", "private", "db" 중 하나 선택
# zone_suffix: "a", "b", "c" - common.naming.tfvars의 region_primary와 자동 결합됨 (예: us-west1-a)
# network_ip: 자동으로 common.naming.tfvars의 vm_static_ips에서 동적 주입됨 (키 이름 기준)
# 인스턴스 키: main.tf에서 "${project_name}-${key}" 형태로 변환됨 (예: gs01 → gcby-gs01)
instances = {
  # Game Server tier (2대) - Private 서브넷 배치
  # 실제 VM 이름: gcby-gs01, gcby-gs02
  # network_ip는 common.naming.tfvars의 vm_static_ips["gs01"], vm_static_ips["gs02"]에서 자동 주입
  "gs01" = {
    zone_suffix       = "a"  # region_primary-a (예: us-west1-a)
    machine_type      = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    boot_disk_size_gb = 128  # 128GB SSD
    boot_disk_type    = "pd-ssd"
    tags              = ["game-server", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "game-server"
      tier = "backend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "private"  # 자동으로 {project_name}-subnet-private 선택
    # network_ip는 common.naming.tfvars vm_static_ips["gs01"] = "10.10.11.3"에서 자동 주입
  }
  "gs02" = {
    zone_suffix       = "b"
    machine_type      = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    boot_disk_size_gb = 128  # 128GB SSD
    boot_disk_type    = "pd-ssd"
    tags              = ["game-server", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "game-server"
      tier = "backend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "private"
    # network_ip는 common.naming.tfvars vm_static_ips["gs02"] = "10.10.11.6"에서 자동 주입
  }

  # # lobby tier (3대) - DMZ 서브넷 배치 - COMMENTED OUT
  # "delabs-lobby-01" = {
  #   zone_suffix  = "a"  # region_primary-a (예: us-west1-a)
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["lobby", "ssh-allowed", "dmz-zone"]
  #   image_family  = "rocky-linux-10-optimized-gcp"
  #   image_project = "rocky-linux-cloud"
  #   labels = {
  #     role = "lobby"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"  # 자동으로 gcby-subnet-dmz 선택
  # }
  # "delabs-lobby-02" = {
  #   zone_suffix = "b"
  #   tags     = ["lobby", "ssh-allowed", "dmz-zone"]
  #   labels = {
  #     role = "lobby"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"
  # }
  # "delabs-lobby-03" = {
  #   zone_suffix = "c"
  #   tags     = ["lobby", "ssh-allowed", "dmz-zone"]
  #   labels = {
  #     role = "lobby"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"
  # }

  # # web tier (3대) - DMZ 서브넷 배치 - COMMENTED OUT
  # "delabs-web-01" = {
  #   zone_suffix  = "a"
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["web", "ssh-allowed", "dmz-zone"]
  #   labels = {
  #     role = "web"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"
  # }
  # "delabs-web-02" = {
  #   zone_suffix  = "b"
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["web", "ssh-allowed", "dmz-zone"]
  #   labels = {
  #     role = "web"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"
  # }
  # "delabs-web-03" = {
  #   zone_suffix  = "c"
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["web", "ssh-allowed", "dmz-zone"]
  #   labels = {
  #     role = "web"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/lobby.sh"
  #   subnet_type         = "dmz"
  # }

  # # WAS tier (2대) - Private 서브넷 배치 - COMMENTED OUT
  # "delabs-was-01" = {
  #   zone_suffix  = "a"
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["was", "ssh-allowed", "private-zone"]
  #   labels = {
  #     role = "was"
  #     tier = "backend"
  #   }
  #   startup_script_file = "scripts/was.sh"
  #   subnet_type         = "private"  # 자동으로 gcby-subnet-private 선택
  # }
  # "delabs-was-02" = {
  #   zone_suffix  = "b"
  #   machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
  #   tags         = ["was", "ssh-allowed", "private-zone"]
  #   labels = {
  #     role = "was"
  #     tier = "backend"
  #   }
  #   startup_script_file = "scripts/was.sh"
  #   image_family        = "rocky-linux-10-optimized-gcp"
  #   image_project       = "rocky-linux-cloud"
  #   subnet_type         = "private"
  # }
}
