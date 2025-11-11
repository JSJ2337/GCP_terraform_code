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
tags = ["game", "ssh-allowed"]
labels = {
  app       = "default-templet"
  component = "game-server"
}

instances = {
  "game-template-web-01" = {
    hostname             = "game-template-web-01"
    zone                 = "us-central1-a"
    machine_type         = "e2-small"
    subnetwork_self_link = "projects/your-project-id/regions/us-central1/subnetworks/your-web-subnet"
    tags                 = ["web", "ssh-allowed"]
    labels = {
      role = "web"
      tier = "frontend"
    }
    startup_script = <<-EOWEB
#!/bin/bash
apt-get update && apt-get install -y nginx
systemctl enable nginx && systemctl start nginx
EOWEB
  }

  "game-template-app-01" = {
    hostname             = "game-template-app-01"
    zone                 = "us-central1-b"
    machine_type         = "e2-standard-2"
    subnetwork_self_link = "projects/your-project-id/regions/us-central1/subnetworks/your-app-subnet"
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
