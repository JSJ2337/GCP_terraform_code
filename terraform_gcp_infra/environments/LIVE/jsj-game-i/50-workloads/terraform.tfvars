# Region Configuration

# Workloads Configuration
# Resource names are generated via modules/naming

# 기존 count 방식 (비활성화)
instance_count = 0

# 새로운 for_each 방식 (권장)
# 각 VM마다 다른 호스트네임, 서브넷, 설정 가능
instances = {
  "game-i-web-01" = {
    hostname             = "web-server-01"
    subnetwork_self_link = "projects/jsj-game-i/regions/asia-northeast3/subnetworks/game-i-prod-subnet-web"
    zone                 = "asia-northeast3-a"
    machine_type         = "e2-small"
    enable_public_ip     = false
    tags                 = ["web", "game", "ssh-allowed"]
    labels = {
      role      = "web"
      component = "frontend"
    }
    startup_script = <<-EOF
#!/bin/bash
apt-get update && apt-get install -y nginx docker.io
systemctl enable nginx docker
systemctl start nginx docker
echo "Web server ready" | logger
EOF
  }

  "game-i-app-01" = {
    hostname             = "app-server-01"
    subnetwork_self_link = "projects/jsj-game-i/regions/asia-northeast3/subnetworks/game-i-prod-subnet-app"
    zone                 = "asia-northeast3-b"
    machine_type         = "e2-medium"
    enable_public_ip     = false
    tags                 = ["app", "game", "ssh-allowed"]
    labels = {
      role      = "app"
      component = "backend"
    }
    startup_script = <<-EOF
#!/bin/bash
apt-get update && apt-get install -y docker.io
systemctl enable docker
systemctl start docker
echo "App server ready" | logger
EOF
  }

  "game-i-db-proxy-01" = {
    hostname             = "db-proxy-01"
    subnetwork_self_link = "projects/jsj-game-i/regions/asia-northeast3/subnetworks/game-i-prod-subnet-db"
    zone                 = "asia-northeast3-c"
    machine_type         = "e2-micro"
    enable_public_ip     = false
    tags                 = ["db-proxy", "ssh-allowed"]
    labels = {
      role      = "database"
      component = "proxy"
    }
    startup_script = <<-EOF
#!/bin/bash
apt-get update
echo "DB proxy ready" | logger
EOF
  }
}

# 기본값 (각 VM에서 override 가능)
machine_type     = "e2-micro"
enable_public_ip = false
enable_os_login  = true
preemptible      = false

# 공통 startup script (instances에서 개별 지정하지 않으면 이게 사용됨)
startup_script = ""

# 공통 tags/labels (instances의 값과 병합됨)
tags = ["game", "prod"]
labels = {
  environment = "prod"
  managed-by  = "terraform"
}
