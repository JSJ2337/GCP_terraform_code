# Project Base Module

This module creates and configures a Google Cloud Project with essential services, budget alerts, and log retention policies.

## Features

- **Project Creation**: Create a GCP project within a folder with billing account association
- **API Management**: Enable required Google Cloud APIs
- **Budget Alerts**: Optional budget monitoring and email notifications
- **Log Retention**: Configure default log retention for the project
- **CMEK Encryption**: Optional customer-managed encryption key for logs
- **Labels**: Apply custom labels for organization and cost tracking

## Usage

### Basic Project

```hcl
module "project" {
  source = "../../modules/project-base"

  project_id      = "my-project-123"
  project_name    = "My Project"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  labels = {
    environment = "prod"
    team        = "platform"
  }
}
```

### Project with Budget Alerts

```hcl
module "project_with_budget" {
  source = "../../modules/project-base"

  project_id      = "my-project-123"
  project_name    = "My Project"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  # Enable budget monitoring
  enable_budget   = true
  budget_amount   = 1000
  budget_currency = "USD"

  # Custom API list
  apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com"
  ]

  # Log configuration
  log_retention_days = 90

  labels = {
    environment = "prod"
    cost_center = "engineering"
  }
}
```

### Project with CMEK Encryption

```hcl
module "secure_project" {
  source = "../../modules/project-base"

  project_id      = "secure-project-123"
  project_name    = "Secure Project"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  # Customer-managed encryption for logs
  cmek_key_id = "projects/kms-project/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key"

  log_retention_days = 365

  labels = {
    environment = "prod"
    compliance  = "pci-dss"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The project ID to create | string | - | yes |
| project_name | Display name for the project | string | "" | no |
| folder_id | Folder ID to create the project in | string | - | yes |
| billing_account | Billing account to associate with the project | string | - | yes |
| labels | Labels to apply to the project | map(string) | {} | no |
| apis | List of APIs to enable | list(string) | See below | no |
| enable_budget | Enable budget monitoring | bool | false | no |
| budget_amount | Budget amount (in specified currency) | number | 100 | no |
| budget_currency | Currency for the budget | string | "USD" | no |
| log_retention_days | Default log retention period in days | number | 30 | no |
| cmek_key_id | Customer-managed encryption key for logs | string | "" | no |

### Default APIs

The module enables the following APIs by default:
- `compute.googleapis.com` - Compute Engine
- `iam.googleapis.com` - Identity and Access Management
- `servicenetworking.googleapis.com` - Service Networking
- `logging.googleapis.com` - Cloud Logging
- `monitoring.googleapis.com` - Cloud Monitoring
- `cloudkms.googleapis.com` - Cloud Key Management Service

## Outputs

| Name | Description |
|------|-------------|
| project_id | The project ID |
| project_number | The project number |
| project_name | The project display name |

## Best Practices

1. **Folder Organization**: Use folders to organize projects by environment, team, or business unit
2. **Budget Alerts**: Enable budget monitoring for production projects to avoid unexpected costs
3. **API Management**: Only enable APIs that are actually needed to reduce attack surface
4. **Labels**: Use consistent labeling strategy for cost allocation and resource management
5. **Log Retention**: Set appropriate log retention based on compliance requirements
6. **CMEK**: Use customer-managed encryption keys for sensitive projects

## Requirements

- Terraform >= 1.6
- Google Provider >= 5.30
- Google Beta Provider >= 5.30 (for budget alerts)

## Permissions Required

To use this module, the service account or user must have:
- `roles/resourcemanager.projectCreator` on the folder
- `roles/billing.user` on the billing account
- `roles/serviceusage.serviceUsageAdmin` to enable APIs

## Notes

- The project will be created with `auto_create_network = false` to avoid creating default networks
- Budget alerts are sent via email to billing account administrators
- Log retention is configured at the project level and applies to all logs
- CMEK encryption for logs requires the key to be created beforehand
