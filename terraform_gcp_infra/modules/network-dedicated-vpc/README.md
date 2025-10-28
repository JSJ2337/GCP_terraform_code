# Network Dedicated VPC Module

This module creates and manages a Google Cloud VPC network with subnets, Cloud NAT, and firewall rules for a dedicated network topology.

## Features

- **VPC Network**: Custom VPC with configurable routing mode (GLOBAL or REGIONAL)
- **Subnets**: Multiple subnets across different regions with secondary IP ranges
- **Private Google Access**: Enable private access to Google APIs
- **Cloud NAT**: Managed NAT gateway for private instances to access the internet
- **Cloud Router**: Required for Cloud NAT and BGP routing
- **Firewall Rules**: Flexible firewall configuration with protocol and port control

## Usage

### Basic VPC with Single Subnet

```hcl
module "vpc" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "my-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region = "us-central1"
      cidr   = "10.0.0.0/24"
    }
  }

  nat_region = "us-central1"
}
```

### VPC with Multiple Subnets and Secondary Ranges

```hcl
module "vpc_multi_region" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "prod-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region                = "us-central1"
      cidr                  = "10.0.0.0/24"
      private_google_access = true
      secondary_ranges = [
        {
          name = "pods"
          cidr = "10.1.0.0/16"
        },
        {
          name = "services"
          cidr = "10.2.0.0/16"
        }
      ]
    }
    subnet-us-east = {
      region                = "us-east1"
      cidr                  = "10.0.1.0/24"
      private_google_access = true
    }
  }

  nat_region           = "us-central1"
  nat_min_ports_per_vm = 2048
}
```

### VPC with Firewall Rules

```hcl
module "vpc_with_firewall" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "secure-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region = "us-central1"
      cidr   = "10.0.0.0/24"
    }
  }

  nat_region = "us-central1"

  firewall_rules = [
    {
      name           = "allow-ssh-from-iap"
      direction      = "INGRESS"
      ranges         = ["35.235.240.0/20"]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      priority       = 1000
      description    = "Allow SSH from Identity-Aware Proxy"
    },
    {
      name           = "allow-internal"
      direction      = "INGRESS"
      ranges         = ["10.0.0.0/8"]
      allow_protocol = "all"
      priority       = 65534
      description    = "Allow internal traffic"
    },
    {
      name           = "allow-http-from-lb"
      direction      = "INGRESS"
      ranges         = ["130.211.0.0/22", "35.191.0.0/16"]
      allow_protocol = "tcp"
      allow_ports    = ["80", "443"]
      target_tags    = ["http-server"]
      priority       = 1000
      description    = "Allow HTTP/HTTPS from load balancers"
    }
  ]
}
```

### Complete Production Example

```hcl
module "prod_network" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "prod-project-123"
  vpc_name     = "prod-vpc"
  routing_mode = "GLOBAL"

  # Multi-region subnets for high availability
  subnets = {
    app-us-central = {
      region                = "us-central1"
      cidr                  = "10.10.0.0/24"
      private_google_access = true
      secondary_ranges = [
        {
          name = "gke-pods"
          cidr = "10.20.0.0/16"
        },
        {
          name = "gke-services"
          cidr = "10.30.0.0/16"
        }
      ]
    }
    app-us-east = {
      region                = "us-east1"
      cidr                  = "10.11.0.0/24"
      private_google_access = true
    }
    db-us-central = {
      region                = "us-central1"
      cidr                  = "10.12.0.0/24"
      private_google_access = true
    }
  }

  # Cloud NAT for outbound internet access
  nat_region           = "us-central1"
  nat_min_ports_per_vm = 2048

  # Comprehensive firewall rules
  firewall_rules = [
    {
      name           = "allow-ssh-iap"
      ranges         = ["35.235.240.0/20"]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      description    = "SSH via IAP"
    },
    {
      name           = "allow-health-checks"
      ranges         = ["35.191.0.0/16", "130.211.0.0/22"]
      allow_protocol = "tcp"
      allow_ports    = ["80", "443"]
      target_tags    = ["http-server"]
      description    = "Health checks from GCP load balancers"
    },
    {
      name           = "allow-internal-all"
      ranges         = ["10.0.0.0/8"]
      allow_protocol = "all"
      priority       = 65534
      description    = "Internal VPC communication"
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| vpc_name | Name of the VPC network | string | - | yes |
| routing_mode | Routing mode (GLOBAL or REGIONAL) | string | "GLOBAL" | no |
| subnets | Map of subnets to create | map(object) | - | yes |
| nat_region | Region to create Cloud NAT | string | - | yes |
| nat_min_ports_per_vm | Minimum ports per VM for NAT | number | 1024 | no |
| firewall_rules | List of firewall rules | list(object) | [] | no |

### Subnet Object Structure

```hcl
{
  region                = string        # Required: GCP region
  cidr                  = string        # Required: IP CIDR range
  private_google_access = bool          # Optional: Enable private Google access (default: true)
  secondary_ranges = list(object({      # Optional: Secondary IP ranges for GKE
    name = string
    cidr = string
  }))
}
```

### Firewall Rule Object Structure

```hcl
{
  name           = string              # Required: Rule name
  direction      = string              # Optional: INGRESS or EGRESS (default: INGRESS)
  ranges         = list(string)        # Optional: Source/destination IP ranges
  allow_protocol = string              # Optional: tcp, udp, icmp, or all (default: tcp)
  allow_ports    = list(string)        # Optional: List of ports (default: [])
  priority       = number              # Optional: Priority (default: 1000)
  target_tags    = list(string)        # Optional: Target network tags
  disabled       = bool                # Optional: Disable rule (default: false)
  description    = string              # Optional: Rule description
}
```

## Outputs

| Name | Description |
|------|-------------|
| vpc_self_link | Self link of the VPC network |
| subnet_ids | Map of subnet names to self links |

## Best Practices

1. **IP Planning**: Plan your CIDR ranges carefully to avoid conflicts
2. **Private Google Access**: Enable for subnets that need to access Google APIs without external IPs
3. **Secondary Ranges**: Use for GKE pod and service IP ranges
4. **NAT Gateway**: Deploy in multiple regions for high availability
5. **Firewall Rules**: Follow least privilege principle - only allow necessary traffic
6. **Network Tags**: Use consistent tagging strategy for firewall rule targeting
7. **Priority**: Use priority ranges to organize rules (e.g., 100-999 for critical, 1000+ for general)

## Common Firewall Rule Examples

### Allow SSH from IAP
```hcl
{
  name           = "allow-ssh-iap"
  ranges         = ["35.235.240.0/20"]
  allow_protocol = "tcp"
  allow_ports    = ["22"]
}
```

### Allow Internal Traffic
```hcl
{
  name           = "allow-internal"
  ranges         = ["10.0.0.0/8"]
  allow_protocol = "all"
  priority       = 65534
}
```

### Allow Load Balancer Health Checks
```hcl
{
  name           = "allow-health-checks"
  ranges         = ["35.191.0.0/16", "130.211.0.0/22"]
  allow_protocol = "tcp"
  allow_ports    = ["80", "443"]
  target_tags    = ["http-server"]
}
```

## Requirements

- Terraform >= 1.6
- Google Provider >= 5.30

## Permissions Required

- `roles/compute.networkAdmin` - To create VPC and subnets
- `roles/compute.securityAdmin` - To create firewall rules

## Notes

- Cloud NAT is created only in the specified `nat_region`
- For multi-region deployments, create separate NAT gateways per region
- Private Google Access allows instances without external IPs to access Google APIs
- Secondary IP ranges are primarily used for GKE clusters (pods and services)
