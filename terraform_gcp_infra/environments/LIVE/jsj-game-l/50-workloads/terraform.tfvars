# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# VM configuration (for_each map 사용)
instance_count    = 0
machine_type      = "e2-micro"
image_family      = "rocky-linux-9"
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
instances = {
  # lobby tier (3대)
  "jsj-lobby-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "e2-small"
    tags         = ["lobby", "ssh-allowed"]
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }
  "jsj-lobby-02" = {
    zone     = "asia-northeast3-b"
    tags     = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }
  "jsj-lobby-03" = {
    zone     = "asia-northeast3-c"
    tags     = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }

  # web tier (3대)
  "jsj-web-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "e2-medium"
    tags         = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }
  "jsj-web-02" = {
    zone         = "asia-northeast3-b"
    machine_type = "e2-medium"
    tags         = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }
  "jsj-web-03" = {
    zone         = "asia-northeast3-c"
    machine_type = "e2-medium"
    tags         = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
  }

  # WAS tier (2대)
  "jsj-was-01" = {
    zone         = "asia-northeast3-a"
    machine_type = "e2-standard-4"
    tags         = ["was", "ssh-allowed"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file  = "scripts/was.sh"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-private"
  }
  "jsj-was-02" = {
    zone         = "asia-northeast3-b"
    machine_type = "e2-standard-4"
    tags         = ["was", "ssh-allowed"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file  = "scripts/was.sh"
    image_family         = "rocky-linux-9"
    image_project        = "rocky-linux-cloud"
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-private"
  }
}

instance_groups = {
  # Web (존별 분리)
  "jsj-web-ig-a" = {
    instances  = ["jsj-web-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-web-ig-b" = {
    instances  = ["jsj-web-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-web-ig-c" = {
    instances  = ["jsj-web-03"]
    zone       = "asia-northeast3-c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # Lobby (존별 분리)
  "jsj-lobby-ig-a" = {
    instances  = ["jsj-lobby-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-lobby-ig-b" = {
    instances  = ["jsj-lobby-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 80 }]
  }
  "jsj-lobby-ig-c" = {
    instances  = ["jsj-lobby-03"]
    zone       = "asia-northeast3-c"
    named_ports = [{ name = "http", port = 80 }]
  }

  # WAS (각 존에 1대씩)
  "jsj-was-ig-a" = {
    instances  = ["jsj-was-01"]
    zone       = "asia-northeast3-a"
    named_ports = [{ name = "http", port = 8080 }]
  }
  "jsj-was-ig-b" = {
    instances  = ["jsj-was-02"]
    zone       = "asia-northeast3-b"
    named_ports = [{ name = "http", port = 8080 }]
  }
}
