# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# VM configuration (use the for_each style by default)
instance_count      = 0
machine_type        = "e2-micro"
image_family        = "debian-12"
image_project       = "debian-cloud"
boot_disk_size_gb   = 30
boot_disk_type      = "pd-balanced"
enable_public_ip    = false
enable_os_login     = true
preemptible         = false
startup_script      = ""
service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
tags = ["prod", "ssh-allowed"]
labels = {
  component = "game-server"
}

# Example: lobby/web/was roles
instances = {
  "tmpl-lobby-01" = {
    hostname             = "tmpl-lobby-01"
    zone                 = "us-central1-a"
    machine_type         = "e2-small"
    subnetwork_self_link = "projects/your-project-id/regions/us-central1/subnetworks/your-web-subnet"
    tags                 = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
  }
  "tmpl-lobby-02" = {
    hostname = "tmpl-lobby-02"
    zone     = "us-central1-b"
    tags     = ["lobby", "ssh-allowed"]
    labels = {
      role = "lobby"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
  }

  "tmpl-web-01" = {
    hostname             = "tmpl-web-01"
    zone                 = "us-central1-a"
    machine_type         = "e2-medium"
    subnetwork_self_link = "projects/your-project-id/regions/us-central1/subnetworks/your-web-subnet"
    tags                 = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
  }
  "tmpl-web-02" = {
    hostname = "tmpl-web-02"
    zone     = "us-central1-b"
    tags     = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script_file = "scripts/lobby.sh"
  }

  "tmpl-was-01" = {
    hostname             = "tmpl-was-01"
    zone                 = "us-central1-c"
    machine_type         = "e2-standard-4"
    subnetwork_self_link = "projects/your-project-id/regions/us-central1/subnetworks/your-app-subnet"
    tags                 = ["was", "ssh-allowed"]
    labels = {
      role = "was"
      tier = "backend"
    }
    startup_script_file = "scripts/was.sh"
  }
}
