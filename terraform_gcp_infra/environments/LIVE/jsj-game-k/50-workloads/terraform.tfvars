# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# VM configuration (use the new for_each map)
instance_count     = 0
machine_type       = "e2-micro"
image_family       = "debian-12"
image_project      = "debian-cloud"
boot_disk_size_gb  = 30
boot_disk_type     = "pd-balanced"
enable_public_ip   = false
enable_os_login    = true
preemptible        = false
startup_script     = ""
tags               = ["game", "ssh-allowed"]
labels = {
  app       = "game-k"
  component = "game-server"
}

instances = {
  "game-k-web-01" = {
    hostname             = "game-k-web-01"
    zone                 = "asia-northeast3-a"
    machine_type         = "e2-small"
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-prod-subnet-asia-northeast3"
    tags                 = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script = <<-EOWEB
#!/bin/bash
apt-get update
apt-get install -y nginx google-fluentd
systemctl enable nginx && systemctl start nginx
systemctl enable google-fluentd && systemctl start google-fluentd
EOWEB
  }

  "game-k-app-01" = {
    hostname             = "game-k-app-01"
    zone                 = "asia-northeast3-b"
    machine_type         = "e2-standard-2"
    subnetwork_self_link = "projects/jsj-game-k/regions/asia-northeast3/subnetworks/game-k-prod-subnet-asia-northeast3"
    enable_public_ip     = false
    tags                 = ["app", "ssh-allowed"]
    labels = {
      role = "app"
      tier = "backend"
    }
    startup_script = <<-EOAPP
#!/bin/bash
apt-get update
apt-get install -y docker.io google-fluentd
systemctl enable docker && systemctl start docker
systemctl enable google-fluentd && systemctl start google-fluentd
EOAPP
  }
}
