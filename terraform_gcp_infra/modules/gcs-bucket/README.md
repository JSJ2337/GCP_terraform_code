# GCS Bucket Module

This module creates and manages a single Google Cloud Storage bucket with comprehensive configuration options.

## Features

- **Security**: Uniform bucket-level access, public access prevention, CMEK encryption
- **Lifecycle Management**: Automated object lifecycle rules
- **Versioning**: Optional object versioning
- **Access Logging**: Optional access log generation
- **CORS**: Cross-origin resource sharing configuration
- **IAM**: Fine-grained access control with conditional bindings
- **Notifications**: Pub/Sub notifications for bucket events
- **Retention Policy**: Bucket-level retention policies

## Usage

### Basic Bucket

```hcl
module "simple_bucket" {
  source = "../../modules/gcs-bucket"

  project_id  = "my-project-id"
  bucket_name = "my-simple-bucket"
  location    = "US"
}
```

### Advanced Bucket with Lifecycle and Versioning

```hcl
module "versioned_bucket" {
  source = "../../modules/gcs-bucket"

  project_id                  = "my-project-id"
  bucket_name                 = "my-versioned-bucket"
  location                    = "US-CENTRAL1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  enable_versioning           = true

  labels = {
    environment = "prod"
    purpose     = "assets"
  }

  lifecycle_rules = [
    {
      condition = {
        num_newer_versions = 3
      }
      action = {
        type = "Delete"
      }
    },
    {
      condition = {
        age = 365
      }
      action = {
        type          = "SetStorageClass"
        storage_class = "ARCHIVE"
      }
    }
  ]

  kms_key_name = "projects/my-project/locations/us-central1/keyRings/my-ring/cryptoKeys/my-key"
}
```

### Bucket with IAM and CORS

```hcl
module "public_assets_bucket" {
  source = "../../modules/gcs-bucket"

  project_id  = "my-project-id"
  bucket_name = "my-public-assets"
  location    = "US"

  cors_rules = [
    {
      origin          = ["https://example.com", "https://www.example.com"]
      method          = ["GET", "HEAD"]
      response_header = ["Content-Type"]
      max_age_seconds = 3600
    }
  ]

  iam_bindings = [
    {
      role    = "roles/storage.objectViewer"
      members = ["allUsers"]
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The project ID | `string` | n/a | yes |
| bucket_name | Name of the bucket (globally unique) | `string` | n/a | yes |
| location | Bucket location | `string` | `"US"` | no |
| storage_class | Storage class | `string` | `"STANDARD"` | no |
| force_destroy | Allow deletion of bucket with objects | `bool` | `false` | no |
| uniform_bucket_level_access | Enable uniform bucket-level access | `bool` | `true` | no |
| labels | Labels to apply | `map(string)` | `{}` | no |
| enable_versioning | Enable object versioning | `bool` | `false` | no |
| lifecycle_rules | Lifecycle management rules | `list(object)` | `[]` | no |
| retention_policy_days | Retention policy in days | `number` | `0` | no |
| kms_key_name | KMS key for encryption | `string` | `""` | no |
| cors_rules | CORS configuration | `list(object)` | `[]` | no |
| public_access_prevention | Public access prevention | `string` | `"enforced"` | no |
| iam_bindings | IAM role bindings | `list(object)` | `[]` | no |
| notifications | Pub/Sub notifications | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the created bucket |
| bucket_url | URL of the bucket |
| bucket_self_link | Self link of the bucket |
| bucket_location | Location of the bucket |
| bucket_storage_class | Storage class of the bucket |

## Security Considerations

1. **Uniform Bucket-Level Access**: Enabled by default for simplified IAM management
2. **Public Access Prevention**: Set to "enforced" by default to prevent accidental public exposure
3. **IAM Bindings**: Uses `google_storage_bucket_iam_member` (non-authoritative) to prevent conflicts
4. **CMEK**: Supports customer-managed encryption keys for data-at-rest encryption

## Best Practices

1. Always use globally unique bucket names
2. Enable versioning for critical data
3. Configure lifecycle rules to optimize storage costs
4. Use CMEK for sensitive data
5. Apply consistent labeling for cost tracking
6. Set appropriate retention policies for compliance
