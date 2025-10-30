# Workloads Configuration
project_id           = "gcp-terraform-imsi"
zone                 = "us-central1-a"
subnetwork_self_link = "projects/gcp-terraform-imsi/regions/us-central1/subnetworks/default-templet-subnet-us-central1"

# VM configuration
instance_count   = 2
name_prefix      = "default-templet-gce"
machine_type     = "e2-micro"
enable_public_ip = false
enable_os_login  = true
preemptible      = false

# Service account
service_account_email = "default-templet-compute@gcp-terraform-imsi.iam.gserviceaccount.com"
service_account_scopes = [
  "https://www.googleapis.com/auth/cloud-platform"
]

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
  app        = "default-templet"
  env        = "prod"
  component  = "game-server"
  managed-by = "terraform"
}