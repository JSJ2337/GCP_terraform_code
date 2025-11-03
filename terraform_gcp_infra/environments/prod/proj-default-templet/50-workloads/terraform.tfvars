# Region Configuration
region = "us-central1"

# Workloads Configuration
# Resource names are auto-generated from ../locals.tf
# VM names will use: vm_name_prefix, subnet names from: subnet_name_primary
project_id = "gcp-terraform-imsi"
zone       = "us-central1-a"

# VM configuration
instance_count = 2
machine_type   = "e2-micro"
enable_public_ip = false
enable_os_login  = true
preemptible      = false

# Startup script
startup_script = <<-EOF
#!/bin/bash
# Update system
apt-get update
apt-get install -y docker.io

# Configure logging
echo "Configuring logging agent..."
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
bash add-logging-agent-repo.sh
apt-get update
apt-get install -y google-fluentd

# Start services
systemctl enable docker
systemctl start docker
systemctl enable google-fluentd
systemctl start google-fluentd

# Game application setup placeholder
echo "Game server setup complete" | logger
EOF

# Tags and labels
tags = ["game", "app", "ssh-allowed"]
labels = {
  app       = "default-templet"
  component = "game-server"
}

