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
  environment = "prod"
  component   = "game-server"
}

# 역할별 인스턴스 정의
# subnet_type: "dmz", "private", "db" 중 하나 선택
instances = {
  # lobby tier (3대) - DMZ 서브넷 배치
  "delabs-lobby-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["lobby", "ssh-allowed", "dmz-zone"]
    image_family  = "rocky-linux-10-optimized-gcp"
    image_project = "rocky-linux-cloud"
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"  # 자동으로 gcby-subnet-dmz 선택
  }
  "delabs-lobby-02" = {
    zone     = "asia-northeast3-b"
    tags     = ["lobby", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "delabs-lobby-03" = {
    zone     = "asia-northeast3-c"
    tags     = ["lobby", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }

  # web tier (3대) - DMZ 서브넷 배치
  "delabs-web-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["web", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "delabs-web-02" = {
    zone         = "asia-northeast3-b"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["web", "ssh-allowed", "dmz-zone"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
    subnet_type         = "dmz"
  }
  "delabs-web-03" = {
    zone         = "asia-northeast3-c"
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
  "delabs-was-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "custom-4-8192"  # 4 vCPUs, 8GB RAM
    tags         = ["was", "ssh-allowed", "private-zone"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
    subnet_type         = "private"  # 자동으로 gcby-subnet-private 선택
  }
  "delabs-was-02" = {
    zone         = "asia-northeast3-b"
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
  "delabs-web-ig-a" = {
    instances  = ["delabs-web-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "delabs-web-ig-b" = {
    instances  = ["delabs-web-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "delabs-web-ig-c" = {
    instances  = ["delabs-web-03"]
    zone       = "asia-northeast3-c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # Lobby (존별 분리)
  "delabs-lobby-ig-a" = {
    instances  = ["delabs-lobby-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "delabs-lobby-ig-b" = {
    instances  = ["delabs-lobby-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "delabs-lobby-ig-c" = {
    instances  = ["delabs-lobby-03"]
    zone       = "asia-northeast3-c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # WAS (각 존에 1대씩)
  "delabs-was-ig-a" = {
    instances  = ["delabs-was-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 8080 }]
  }
  "delabs-was-ig-b" = {
    instances  = ["delabs-was-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 8080 }]
  }
}
