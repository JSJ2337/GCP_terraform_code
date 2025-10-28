# GCE VM Set Module

This module creates and manages a set of Google Compute Engine instances with consistent configuration.

## Features

- **Multiple Instances**: Create multiple identical instances in a single zone
- **Image Selection**: Support for custom images and public image families
- **Disk Configuration**: Configurable boot disk size and type
- **Network Configuration**: Support for private or public IP addresses
- **Service Accounts**: Attach custom or default service accounts
- **Startup Scripts**: Run initialization scripts on instance boot
- **Preemptible/Spot**: Support for cost-effective preemptible instances
- **OS Login**: Enable Google Cloud OS Login for SSH access
- **Metadata and Labels**: Custom instance metadata and labels
- **Network Tags**: Apply tags for firewall rule targeting

## Usage

### Basic VM Set

```hcl
module "app_vms" {
  source = "../../modules/gce-vmset"

  project_id           = "my-project-id"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/my-subnet"

  instance_count = 3
  name_prefix    = "app-server"
  machine_type   = "e2-medium"
}
```

### Production VM Set with Custom Configuration

```hcl
module "prod_app_servers" {
  source = "../../modules/gce-vmset"

  project_id           = "prod-project-123"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/prod-project-123/regions/us-central1/subnetworks/prod-subnet"

  instance_count = 5
  name_prefix    = "prod-app"
  machine_type   = "n2-standard-4"

  # Operating system
  image_family  = "ubuntu-2204-lts"
  image_project = "ubuntu-os-cloud"

  # Disk configuration
  boot_disk_size_gb = 50
  boot_disk_type    = "pd-ssd"

  # Network
  enable_public_ip = false

  # Security
  enable_os_login = true

  # Service account
  service_account_email = "app-backend@prod-project-123.iam.gserviceaccount.com"
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # Startup script
  startup_script = file("${path.module}/scripts/install-app.sh")

  # Metadata
  metadata = {
    environment = "production"
    app_version = "v2.1.0"
  }

  # Network tags for firewall rules
  tags = ["http-server", "app-backend"]

  # Labels for organization
  labels = {
    environment = "prod"
    component   = "backend"
    managed_by  = "terraform"
  }
}
```

### Cost-Optimized Development Environment

```hcl
module "dev_vms" {
  source = "../../modules/gce-vmset"

  project_id           = "dev-project-123"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/dev-project-123/regions/us-central1/subnetworks/dev-subnet"

  instance_count = 2
  name_prefix    = "dev-test"

  # Use spot instances for cost savings
  machine_type = "e2-small"
  preemptible  = true

  # Minimal disk
  boot_disk_size_gb = 10
  boot_disk_type    = "pd-standard"

  # Allow public IP for development access
  enable_public_ip = true

  tags = ["dev-environment"]

  labels = {
    environment = "dev"
    auto_delete = "true"
  }
}
```

### Database Servers with Custom Setup

```hcl
module "db_servers" {
  source = "../../modules/gce-vmset"

  project_id           = "prod-project-123"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/prod-project-123/regions/us-central1/subnetworks/db-subnet"

  instance_count = 3
  name_prefix    = "db-node"
  machine_type   = "n2-highmem-4"

  # Database-optimized image
  image_family  = "ubuntu-2204-lts"
  image_project = "ubuntu-os-cloud"

  # Large SSD disk for database
  boot_disk_size_gb = 500
  boot_disk_type    = "pd-ssd"

  # Private network only
  enable_public_ip = false

  # Custom startup script to install and configure database
  startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update
    apt-get install -y postgresql-15

    # Configure PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql

    # Custom configuration
    echo "Database initialized" > /var/log/setup-complete
  EOF

  # Service account with database permissions
  service_account_email = "db-service@prod-project-123.iam.gserviceaccount.com"

  # Network tags for database firewall rules
  tags = ["db-server", "postgresql"]

  # Metadata for configuration management
  metadata = {
    db_cluster  = "prod-primary"
    db_role     = "replica"
    backup_time = "02:00"
  }

  labels = {
    environment = "prod"
    tier        = "database"
    managed_by  = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| zone | GCP zone for instances | string | - | yes |
| subnetwork_self_link | Subnetwork self link | string | - | yes |
| instance_count | Number of instances to create | number | 4 | no |
| name_prefix | Prefix for instance names | string | "gce-node" | no |
| machine_type | Machine type | string | "e2-standard-2" | no |
| image_family | OS image family | string | "debian-12" | no |
| image_project | Project containing the image | string | "debian-cloud" | no |
| boot_disk_size_gb | Boot disk size in GB | number | 20 | no |
| boot_disk_type | Boot disk type | string | "pd-balanced" | no |
| enable_public_ip | Enable external IP | bool | false | no |
| enable_os_login | Enable OS Login | bool | true | no |
| preemptible | Use preemptible (spot) instances | bool | false | no |
| service_account_email | Service account email | string | "" | no |
| service_account_scopes | Service account scopes | list(string) | ["cloud-platform"] | no |
| startup_script | Startup script to run on boot | string | "" | no |
| metadata | Instance metadata | map(string) | {} | no |
| tags | Network tags | list(string) | [] | no |
| labels | Instance labels | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_names | List of instance names |
| instance_self_links | List of instance self links |
| private_ips | List of private IP addresses |
| public_ips | List of public IP addresses (if enabled) |

## Machine Types

### General Purpose (E2)
- `e2-micro` - 0.25-2 vCPU, 1 GB RAM
- `e2-small` - 0.5-2 vCPU, 2 GB RAM
- `e2-medium` - 1-2 vCPU, 4 GB RAM
- `e2-standard-2` - 2 vCPU, 8 GB RAM
- `e2-standard-4` - 4 vCPU, 16 GB RAM

### Compute-Optimized (C2/C2D)
- `c2-standard-4` - 4 vCPU, 16 GB RAM
- `c2-standard-8` - 8 vCPU, 32 GB RAM
- `c2d-standard-4` - 4 vCPU, 16 GB RAM

### Memory-Optimized (M2/M1)
- `n2-highmem-2` - 2 vCPU, 16 GB RAM
- `n2-highmem-4` - 4 vCPU, 32 GB RAM
- `m1-ultramem-40` - 40 vCPU, 961 GB RAM

### General Purpose (N2/N2D)
- `n2-standard-2` - 2 vCPU, 8 GB RAM
- `n2-standard-4` - 4 vCPU, 16 GB RAM
- `n2d-standard-2` - 2 vCPU, 8 GB RAM

## Popular Image Families

### Debian
- `debian-11` - Debian 11 (Bullseye)
- `debian-12` - Debian 12 (Bookworm)

### Ubuntu
- `ubuntu-2004-lts` - Ubuntu 20.04 LTS
- `ubuntu-2204-lts` - Ubuntu 22.04 LTS
- `ubuntu-2404-lts-amd64` - Ubuntu 24.04 LTS

### CentOS/Rocky/AlmaLinux
- `rocky-linux-8` - Rocky Linux 8
- `rocky-linux-9` - Rocky Linux 9
- `almalinux-8` - AlmaLinux 8

### Windows
- `windows-2019` - Windows Server 2019
- `windows-2022` - Windows Server 2022

### Container-Optimized OS
- `cos-stable` - Container-Optimized OS (stable)
- `cos-beta` - Container-Optimized OS (beta)

## Disk Types

| Type | Description | IOPS | Use Case |
|------|-------------|------|----------|
| `pd-standard` | Standard persistent disk | Lower | Archive, backup |
| `pd-balanced` | Balanced persistent disk | Medium | General purpose (default) |
| `pd-ssd` | SSD persistent disk | High | Databases, high I/O |
| `pd-extreme` | Extreme persistent disk | Very High | Mission-critical databases |

## Service Account Scopes

### Cloud Platform (Full Access)
```hcl
service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
```

### Limited Scopes (Recommended)
```hcl
service_account_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring.write",
  "https://www.googleapis.com/auth/devstorage.read_only"
]
```

## Best Practices

1. **Use Private IPs**: Set `enable_public_ip = false` for security
2. **Enable OS Login**: Use `enable_os_login = true` for centralized SSH key management
3. **Service Accounts**: Create dedicated service accounts, avoid default
4. **Machine Sizing**: Right-size instances to avoid over-provisioning
5. **Spot Instances**: Use `preemptible = true` for non-critical workloads
6. **Startup Scripts**: Use for initial configuration and bootstrapping
7. **Labels**: Use consistent labeling for cost tracking and organization
8. **Network Tags**: Apply tags for firewall rule management
9. **Disk Type**: Use `pd-balanced` for general purpose, `pd-ssd` for high I/O
10. **Metadata**: Store configuration in metadata for instance identification

## Security Considerations

- **No Public IPs**: Use Cloud NAT or bastion hosts for outbound access
- **OS Login**: Enable for secure, auditable SSH access
- **Service Accounts**: Use least privilege principle
- **Startup Scripts**: Avoid embedding secrets (use Secret Manager instead)
- **Firewall Rules**: Apply network tags and create specific rules
- **Disk Encryption**: Disks are encrypted by default with Google-managed keys
- **Shielded VMs**: Consider enabling Secure Boot and vTPM

## Cost Optimization

1. **Preemptible/Spot Instances**: Save up to 80% for fault-tolerant workloads
2. **Right-Sizing**: Match machine type to actual resource needs
3. **Committed Use Discounts**: Save up to 57% with 1 or 3-year commits
4. **Sustained Use Discounts**: Automatic discounts for continuous usage
5. **Disk Type**: Use `pd-standard` for low I/O workloads
6. **Instance Scheduling**: Stop instances during off-hours

## Startup Script Examples

### Basic System Update
```bash
#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
```

### Docker Installation
```bash
#!/bin/bash
apt-get update
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker $(whoami)
```

### Application Deployment
```bash
#!/bin/bash
# Install dependencies
apt-get update
apt-get install -y git python3-pip

# Clone and setup application
cd /opt
git clone https://github.com/company/app.git
cd app
pip3 install -r requirements.txt

# Create systemd service
cat > /etc/systemd/system/app.service <<EOF
[Unit]
Description=Application Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable app
systemctl start app
```

## Requirements

- Terraform >= 1.6
- Google Provider >= 5.30

## Permissions Required

- `roles/compute.instanceAdmin.v1` - To create and manage instances
- `roles/iam.serviceAccountUser` - To attach service accounts

## Notes

- Instances are named as `{name_prefix}-{index}` (e.g., `app-server-0`, `app-server-1`)
- If `service_account_email` is empty, the default Compute Engine service account is used
- Preemptible instances can be terminated at any time by Google Cloud
- OS Login requires the user to have appropriate IAM roles
- Startup scripts run as root user
- Maximum boot disk size depends on the image (check GCP documentation)
