# GCS Root Module

This module manages multiple Google Cloud Storage buckets with common default settings.

## Purpose

The `gcs-root` module is a wrapper around the `gcs-bucket` module that allows you to create and manage multiple GCS buckets with:
- Shared default labels
- Common KMS encryption key
- Unified public access prevention settings
- Individual bucket-specific configurations

## Usage

```hcl
module "storage" {
  source = "../../modules/gcs-root"

  project_id                      = "my-project-id"
  default_labels                  = {
    environment = "prod"
    managed_by  = "terraform"
  }
  default_kms_key_name            = "projects/my-project/locations/us/keyRings/my-ring/cryptoKeys/my-key"
  default_public_access_prevention = "enforced"

  buckets = {
    assets = {
      name          = "my-assets-bucket"
      location      = "US-CENTRAL1"
      storage_class = "STANDARD"
      enable_versioning = true
      cors_rules = [{
        origin = ["https://example.com"]
        method = ["GET"]
      }]
    }
    logs = {
      name              = "my-logs-bucket"
      storage_class     = "COLDLINE"
      retention_policy_days = 90
    }
  }
}
```

## Features

- **DRY Configuration**: Define common settings once for all buckets
- **Flexible Overrides**: Each bucket can override default settings
- **Consistent Labeling**: Apply organization-wide labels automatically
- **Security by Default**: Enforce uniform bucket-level access and public access prevention

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The project ID to create buckets in | `string` | n/a | yes |
| buckets | Map of bucket configurations | `map(object)` | n/a | yes |
| default_labels | Default labels to apply to all buckets | `map(string)` | `{}` | no |
| default_kms_key_name | Default KMS key name for bucket encryption | `string` | `""` | no |
| default_public_access_prevention | Default public access prevention setting | `string` | `"enforced"` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_names | Map of bucket keys to bucket names |
| bucket_urls | Map of bucket keys to bucket URLs |
| bucket_self_links | Map of bucket keys to bucket self links |
| bucket_locations | Map of bucket keys to bucket locations |
| bucket_storage_classes | Map of bucket keys to storage classes |

## When to Use This Module

Use `gcs-root` when:
- You need to create multiple buckets with similar configurations
- You want to enforce consistent labeling and security settings
- You need centralized management of bucket encryption keys

Use `gcs-bucket` directly when:
- You only need a single bucket
- Each bucket has completely different configurations
