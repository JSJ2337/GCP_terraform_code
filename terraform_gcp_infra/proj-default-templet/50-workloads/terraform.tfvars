# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# VM configuration (for_each map 사용)
instance_count    = 0
machine_type      = "custom-4-8192"  # 4 vCPUs, 8GB RAM
image_family      = "rocky-linux-10-optimized-gcp"
image_project     = "rocky-linux-cloud"
boot_disk_size_gb = 30
boot_disk_type    = "pd-balanced"
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
# zone_suffix: "a", "b", "c" - common.naming.tfvars의 region_primary와 자동 결합됨 (예: asia-northeast3-a)
instances = {
  # lobby tier (3대) - DMZ 서브넷 배치
  "jsj-lobby-01" = {
    zone_suffix  = "a"  # region_primary-a (예: asia-northeast3-a)
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["lobby", "ssh-allowed", "dmz-zone"]
    image_family  = "rocky-linux-10-optimized-gcp"
    image_project = "rocky-linux-cloud"
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"  # 자동으로 {project_name}-subnet-dmz 선택
  }
  "jsj-lobby-02" = {
    zone_suffix = "b"
    tags     = ["lobby", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "jsj-lobby-03" = {
    zone_suffix = "c"
    tags     = ["lobby", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }

  # web tier (3대) - DMZ 서브넷 배치
  "jsj-web-01" = {
    zone_suffix  = "a"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["web", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "jsj-web-02" = {
    zone_suffix  = "b"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["web", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "jsj-web-03" = {
    zone_suffix  = "c"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["web", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }

  # WAS tier (2대) - Private 서브넷 배치
  "jsj-was-01" = {
    zone_suffix  = "a"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["was", "ssh-allowed", "private-zone"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "private"  # 자동으로 {project_name}-subnet-private 선택
  }
  "jsj-was-02" = {
    zone_suffix  = "b"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["was", "ssh-allowed", "private-zone"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
    image_family        = "rocky-linux-10-optimized-gcp"
    image_project       = "rocky-linux-cloud"
    subnet_type         = "private"
  }
}

instance_groups = {
  # Web (존별 분리)
  "jsj-web-ig-a" = {
    instances  = ["jsj-web-01"]
    zone_suffix = "a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-web-ig-b" = {
    instances  = ["jsj-web-02"]
    zone_suffix = "b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-web-ig-c" = {
    instances  = ["jsj-web-03"]
    zone_suffix = "c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # Lobby (존별 분리)
  "jsj-lobby-ig-a" = {
    instances  = ["jsj-lobby-01"]
    zone_suffix = "a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-lobby-ig-b" = {
    instances  = ["jsj-lobby-02"]
    zone_suffix = "b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-lobby-ig-c" = {
    instances  = ["jsj-lobby-03"]
    zone_suffix = "c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # WAS (각 존에 1대씩)
  "jsj-was-ig-a" = {
    instances  = ["jsj-was-01"]
    zone_suffix = "a"
    named_ports = [{ name = "http", port = 8080 }]
  }
  "jsj-was-ig-b" = {
    instances  = ["jsj-was-02"]
    zone_suffix = "b"
    named_ports = [{ name = "http", port = 8080 }]
  }
}
