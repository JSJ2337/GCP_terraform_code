# IAM Module

This module manages Google Cloud IAM bindings at the project level and optionally creates service accounts.

## Features

- **IAM Bindings**: Add members to project-level IAM roles (non-authoritative)
- **Service Accounts**: Create and manage service accounts
- **Non-Authoritative**: Uses `google_project_iam_member` to safely add permissions without affecting existing bindings
- **Flexible Configuration**: Support for users, groups, and service accounts

## Usage

### Basic IAM Bindings

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id = "my-project-id"

  bindings = [
    {
      role   = "roles/compute.viewer"
      member = "user:alice@example.com"
    },
    {
      role   = "roles/storage.admin"
      member = "group:platform-team@example.com"
    },
    {
      role   = "roles/logging.viewer"
      member = "serviceAccount:app@my-project.iam.gserviceaccount.com"
    }
  ]
}
```

### Creating Service Accounts with IAM Bindings

```hcl
module "iam_with_sa" {
  source = "../../modules/iam"

  project_id = "my-project-id"

  # Create service accounts
  create_service_accounts = true

  service_accounts = [
    {
      account_id   = "app-backend"
      display_name = "Backend Application Service Account"
      description  = "Service account for backend API"
    },
    {
      account_id   = "data-pipeline"
      display_name = "Data Pipeline Service Account"
      description  = "Service account for ETL jobs"
    }
  ]

  # Grant permissions to service accounts and users
  bindings = [
    {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:app-backend@my-project.iam.gserviceaccount.com"
    },
    {
      role   = "roles/bigquery.dataEditor"
      member = "serviceAccount:data-pipeline@my-project.iam.gserviceaccount.com"
    },
    {
      role   = "roles/iam.serviceAccountUser"
      member = "user:developer@example.com"
    }
  ]
}
```

### Complete Production Example

```hcl
module "prod_iam" {
  source = "../../modules/iam"

  project_id = "prod-project-123"

  # Create application service accounts
  create_service_accounts = true

  service_accounts = [
    {
      account_id   = "prod-app"
      display_name = "Production Application"
      description  = "Main application service account"
    },
    {
      account_id   = "prod-monitoring"
      display_name = "Monitoring Agent"
      description  = "Service account for monitoring and logging"
    },
    {
      account_id   = "prod-backup"
      display_name = "Backup Service"
      description  = "Service account for backup operations"
    }
  ]

  # IAM bindings for different roles
  bindings = [
    # Application permissions
    {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:prod-app@prod-project-123.iam.gserviceaccount.com"
    },
    {
      role   = "roles/cloudsql.client"
      member = "serviceAccount:prod-app@prod-project-123.iam.gserviceaccount.com"
    },

    # Monitoring permissions
    {
      role   = "roles/monitoring.metricWriter"
      member = "serviceAccount:prod-monitoring@prod-project-123.iam.gserviceaccount.com"
    },
    {
      role   = "roles/logging.logWriter"
      member = "serviceAccount:prod-monitoring@prod-project-123.iam.gserviceaccount.com"
    },

    # Backup permissions
    {
      role   = "roles/storage.admin"
      member = "serviceAccount:prod-backup@prod-project-123.iam.gserviceaccount.com"
    },

    # Team access
    {
      role   = "roles/viewer"
      member = "group:developers@example.com"
    },
    {
      role   = "roles/editor"
      member = "group:platform-team@example.com"
    },
    {
      role   = "roles/owner"
      member = "user:admin@example.com"
    }
  ]
}
```

### Member Format Examples

```hcl
# User
member = "user:alice@example.com"

# Group
member = "group:developers@example.com"

# Service Account
member = "serviceAccount:app@project-id.iam.gserviceaccount.com"

# Domain
member = "domain:example.com"

# All Authenticated Users
member = "allAuthenticatedUsers"

# All Users (public)
member = "allUsers"
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| bindings | List of IAM role bindings | list(object) | [] | no |
| create_service_accounts | Whether to create service accounts | bool | false | no |
| service_accounts | List of service accounts to create | list(object) | [] | no |

### Bindings Object Structure

```hcl
{
  role   = string  # Required: IAM role (e.g., "roles/storage.admin")
  member = string  # Required: Member identity (e.g., "user:alice@example.com")
}
```

### Service Account Object Structure

```hcl
{
  account_id   = string  # Required: Service account ID (max 30 chars, lowercase, hyphens)
  display_name = string  # Optional: Human-readable name
  description  = string  # Optional: Description of the service account
}
```

## Outputs

| Name | Description |
|------|-------------|
| service_accounts | Map of service account IDs to email addresses |

## Common IAM Roles

### Compute Engine
- `roles/compute.viewer` - Read-only access
- `roles/compute.instanceAdmin.v1` - Manage instances
- `roles/compute.networkAdmin` - Manage networks

### Storage
- `roles/storage.objectViewer` - Read objects
- `roles/storage.objectCreator` - Create objects
- `roles/storage.objectAdmin` - Full object control
- `roles/storage.admin` - Full bucket and object control

### BigQuery
- `roles/bigquery.dataViewer` - Read data
- `roles/bigquery.dataEditor` - Read and write data
- `roles/bigquery.admin` - Full access

### Cloud SQL
- `roles/cloudsql.client` - Connect to instances
- `roles/cloudsql.editor` - Manage instances
- `roles/cloudsql.admin` - Full access

### Logging and Monitoring
- `roles/logging.viewer` - View logs
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write metrics
- `roles/monitoring.viewer` - View metrics

### General
- `roles/viewer` - Read-only access to all resources
- `roles/editor` - Edit access to all resources
- `roles/owner` - Full access including IAM management

## Best Practices

1. **Least Privilege**: Grant only the minimum required permissions
2. **Use Groups**: Assign roles to groups rather than individual users
3. **Service Accounts**: Create dedicated service accounts for each application
4. **Avoid Owner Role**: Use more specific roles instead of `roles/owner`
5. **Regular Audits**: Review IAM bindings regularly
6. **Naming Convention**: Use consistent naming for service accounts (e.g., `app-name-purpose`)
7. **Documentation**: Document the purpose of each service account
8. **Non-Authoritative**: This module uses non-authoritative bindings, which is safer

## Security Considerations

- **Avoid allUsers and allAuthenticatedUsers** in production
- **Rotate service account keys** regularly
- **Enable audit logging** for IAM changes
- **Use workload identity** for GKE instead of service account keys
- **Review permissions** before granting editor or owner roles

## Requirements

- Terraform >= 1.6
- Google Provider >= 5.30

## Permissions Required

- `roles/iam.serviceAccountAdmin` - To create service accounts
- `roles/resourcemanager.projectIamAdmin` - To manage project IAM bindings

## Notes

- This module uses `google_project_iam_member` (non-authoritative), which means:
  - It only manages the specific bindings you define
  - It won't remove existing bindings created elsewhere
  - Multiple Terraform modules can safely add bindings to the same role
- Service account email format: `{account_id}@{project_id}.iam.gserviceaccount.com`
- Service account `account_id` must be 6-30 characters, lowercase letters, digits, and hyphens
