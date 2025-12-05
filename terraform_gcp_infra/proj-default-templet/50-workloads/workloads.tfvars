# =============================================================================
# Workloads Configuration
# =============================================================================
# Resource names are generated via modules/naming
# VM 인스턴스 키는 main.tf에서 "${project_name}-${key}" 형태로 변환됨

# Region Configuration
# region은 terragrunt.hcl에서 region_primary 자동 주입

# =============================================================================
# VM Default Configuration
# =============================================================================
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

# =============================================================================
# 역할별 인스턴스 정의
# =============================================================================
# subnet_type: "dmz", "private", "psc" 중 하나 선택
# zone_suffix: "a", "b", "c" - common.naming.tfvars의 region_primary와 자동 결합됨
# network_ip: common.naming.tfvars의 vm_static_ips에서 동적 주입됨 (키 이름 기준)
# 인스턴스 키: main.tf에서 "${project_name}-${key}" 형태로 변환됨

instances = {
  # =============================================================================
  # Game Server 예시 (필요에 따라 수정)
  # =============================================================================
  # 실제 VM 이름: {project_name}-gs01, {project_name}-gs02
  # network_ip는 common.naming.tfvars의 vm_static_ips["gs01"], vm_static_ips["gs02"]에서 자동 주입

  # "gs01" = {
  #   zone_suffix       = "a"
  #   machine_type      = "custom-4-8192"
  #   boot_disk_size_gb = 128
  #   boot_disk_type    = "pd-ssd"
  #   tags              = ["game-server", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
  #   image_family      = "rocky-linux-10-optimized-gcp"
  #   image_project     = "rocky-linux-cloud"
  #   labels = {
  #     role = "game-server"
  #     tier = "backend"
  #   }
  #   startup_script_file = "scripts/game.sh"
  #   subnet_type         = "private"
  # }

  # "gs02" = {
  #   zone_suffix       = "b"
  #   machine_type      = "custom-4-8192"
  #   boot_disk_size_gb = 128
  #   boot_disk_type    = "pd-ssd"
  #   tags              = ["game-server", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
  #   image_family      = "rocky-linux-10-optimized-gcp"
  #   image_project     = "rocky-linux-cloud"
  #   labels = {
  #     role = "game-server"
  #     tier = "backend"
  #   }
  #   startup_script_file = "scripts/game.sh"
  #   subnet_type         = "private"
  # }

  # =============================================================================
  # Web/Lobby Server 예시 (DMZ 배치)
  # =============================================================================
  # "web01" = {
  #   zone_suffix       = "a"
  #   machine_type      = "custom-2-4096"
  #   boot_disk_size_gb = 64
  #   boot_disk_type    = "pd-ssd"
  #   tags              = ["web", "ssh-from-iap", "dmz-zone"]
  #   image_family      = "rocky-linux-10-optimized-gcp"
  #   image_project     = "rocky-linux-cloud"
  #   labels = {
  #     role = "web"
  #     tier = "frontend"
  #   }
  #   startup_script_file = "scripts/web.sh"
  #   subnet_type         = "dmz"
  # }
}
