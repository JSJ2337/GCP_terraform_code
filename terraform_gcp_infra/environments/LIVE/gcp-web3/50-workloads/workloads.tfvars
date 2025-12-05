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
  # WWW Server (3대) - DMZ 배치
  # =============================================================================
  "www01" = {
    zone_suffix       = "a"
    machine_type      = "custom-4-8192"
    boot_disk_size_gb = 128
    boot_disk_type    = "pd-ssd"
    tags              = ["www", "ssh-from-iap", "ssh-from-mgmt", "dmz-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "www"
      tier = "frontend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "dmz"
  }

  "www02" = {
    zone_suffix       = "b"
    machine_type      = "custom-4-8192"
    boot_disk_size_gb = 128
    boot_disk_type    = "pd-ssd"
    tags              = ["www", "ssh-from-iap", "ssh-from-mgmt", "dmz-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "www"
      tier = "frontend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "dmz"
  }

  "www03" = {
    zone_suffix       = "c"
    machine_type      = "custom-4-8192"
    boot_disk_size_gb = 128
    boot_disk_type    = "pd-ssd"
    tags              = ["www", "ssh-from-iap", "ssh-from-mgmt", "dmz-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "www"
      tier = "frontend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "dmz"
  }

  # =============================================================================
  # Mint Server (2대) - Private 배치
  # =============================================================================
  "mint01" = {
    zone_suffix       = "a"
    machine_type      = "custom-4-8192"
    boot_disk_size_gb = 128
    boot_disk_type    = "pd-ssd"
    tags              = ["mint", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "mint"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "private"
  }

  "mint02" = {
    zone_suffix       = "b"
    machine_type      = "custom-4-8192"
    boot_disk_size_gb = 128
    boot_disk_type    = "pd-ssd"
    tags              = ["mint", "ssh-from-iap", "ssh-from-mgmt", "private-zone"]
    image_family      = "rocky-linux-10-optimized-gcp"
    image_project     = "rocky-linux-cloud"
    labels = {
      role = "mint"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "private"
  }
}
