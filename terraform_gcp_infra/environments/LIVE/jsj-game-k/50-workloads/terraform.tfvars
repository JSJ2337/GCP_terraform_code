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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
  }
  "jsj-lobby-02" = {
    zone     = "asia-northeast3-b"
    tags     = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
  }
  "jsj-lobby-03" = {
    zone     = "asia-northeast3-c"
    tags     = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file  = "scripts/lobby.sh"
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-private"
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
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-private"
  }
}

mig_groups = {
  "jsj-web-mig" = {
    zone                 = "asia-northeast3-a"
    target_size          = 2
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-subnet-dmz"
    named_ports = [
      { name = "http", port = 80 }
    ]
    startup_script_file = "scripts/lobby.sh"
    machine_type        = "e2-medium"
    image_family        = "rocky-linux-9"
    image_project       = "rocky-linux-cloud"
  }
}
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
    image_family  = "rocky-linux-9"
    image_project = "rocky-linux-cloud"
