# Observability Module

This module configures Google Cloud Logging and Monitoring for centralized log aggregation and custom dashboards.

## Features

- **Centralized Logging**: Export logs from project to a central logging bucket
- **Log Filtering**: Configure which logs to export using advanced filters
- **Unique Writer Identity**: Automatically create service account for log sink
- **Monitoring Dashboards**: Import custom Cloud Monitoring dashboards from JSON files
- **Multi-Dashboard Support**: Deploy multiple dashboards from file references

## Usage

### Basic Log Sink to Central Project

```hcl
module "observability" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  enable_central_log_sink = true
  central_logging_project = "logging-project-456"
  central_logging_bucket  = "central-logs"
}
```

### Log Sink with Custom Filter

```hcl
module "observability_filtered" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  enable_central_log_sink = true
  central_logging_project = "logging-project-456"
  central_logging_bucket  = "central-logs"

  # Only export error and critical logs
  log_filter = <<-EOT
    severity >= ERROR
  EOT
}
```

### Monitoring Dashboards Only

```hcl
module "monitoring" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  # Import dashboards from JSON files
  dashboard_json_files = [
    "./dashboards/application-metrics.json",
    "./dashboards/infrastructure-health.json"
  ]
}
```

### Complete Observability Setup

```hcl
module "prod_observability" {
  source = "../../modules/observability"

  project_id = "prod-app-123"

  # Central logging configuration
  enable_central_log_sink = true
  central_logging_project = "prod-logging-central"
  central_logging_bucket  = "prod-logs-aggregated"

  # Filter to export only important logs
  log_filter = <<-EOT
    (
      severity >= WARNING
      OR
      resource.type = "gce_instance"
      OR
      resource.type = "cloud_run_revision"
    )
    AND NOT (
      resource.labels.name = "health-check"
    )
  EOT

  # Import monitoring dashboards
  dashboard_json_files = [
    "./dashboards/overview.json",
    "./dashboards/compute-resources.json",
    "./dashboards/application-latency.json",
    "./dashboards/error-rates.json"
  ]
}

# Grant permissions to log sink writer
resource "google_project_iam_member" "log_sink_writer" {
  project = "prod-logging-central"
  role    = "roles/logging.bucketWriter"
  member  = module.prod_observability.log_sink_writer_identity
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| enable_central_log_sink | Enable centralized log export | bool | false | no |
| central_logging_project | Project ID where logs will be sent | string | "" | no |
| central_logging_bucket | Log bucket name in central project | string | "_Default" | no |
| log_filter | Advanced filter for logs to export | string | "" | no |
| dashboard_json_files | List of dashboard JSON file paths | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| log_sink_writer_identity | Service account identity for log sink (needs bucket write permission) |

## Log Filter Examples

### All Logs (Default)
```hcl
log_filter = ""
```

### Errors and Critical Only
```hcl
log_filter = "severity >= ERROR"
```

### Specific Resource Types
```hcl
log_filter = <<-EOT
  resource.type = ("gce_instance" OR "cloud_run_revision" OR "k8s_container")
EOT
```

### Application Logs Only
```hcl
log_filter = <<-EOT
  logName =~ "projects/.*/logs/app-*"
EOT
```

### Exclude Health Checks
```hcl
log_filter = <<-EOT
  NOT (
    httpRequest.requestUrl =~ "/health"
    OR
    httpRequest.requestUrl =~ "/readiness"
  )
EOT
```

### Complex Production Filter
```hcl
log_filter = <<-EOT
  (
    -- Include all errors
    severity >= ERROR
    OR
    -- Include specific resources
    (
      resource.type = "gce_instance"
      AND severity >= WARNING
    )
    OR
    -- Include audit logs
    protoPayload.@type = "type.googleapis.com/google.cloud.audit.AuditLog"
  )
  AND NOT (
    -- Exclude health check logs
    httpRequest.requestUrl =~ "/health"
    OR
    -- Exclude specific services
    resource.labels.service_name = "internal-monitoring"
  )
EOT
```

## Dashboard Configuration

### Creating Dashboard JSON Files

1. Create dashboard in Cloud Console
2. Export dashboard JSON:
   ```bash
   gcloud monitoring dashboards describe DASHBOARD_ID \
     --project=PROJECT_ID \
     --format=json > dashboard.json
   ```

3. Reference in Terraform:
   ```hcl
   dashboard_json_files = ["./dashboards/dashboard.json"]
   ```

### Dashboard JSON Structure (Simplified)

```json
{
  "displayName": "Application Metrics",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "CPU Utilization",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"gce_instance\"",
                    "aggregation": {
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
```

## Best Practices

### Logging

1. **Central Logging**: Use a dedicated project for log aggregation
2. **Log Filtering**: Export only necessary logs to reduce costs
3. **Retention Policies**: Configure appropriate retention in central bucket
4. **Access Control**: Restrict access to central logging project
5. **Cost Management**: Monitor logging costs and adjust filters

### Monitoring

1. **Dashboard Organization**: Create separate dashboards for different concerns
2. **Key Metrics**: Include SLIs (Service Level Indicators) in dashboards
3. **Alerting**: Complement dashboards with alerting policies
4. **Version Control**: Store dashboard JSON files in version control
5. **Documentation**: Document dashboard purpose and metrics

## Common Log Filter Patterns

### By Severity
```
severity >= WARNING
severity = ERROR
severity >= CRITICAL
```

### By Resource Type
```
resource.type = "gce_instance"
resource.type = "k8s_pod"
resource.type = "cloud_function"
```

### By Log Name
```
logName =~ "projects/.*/logs/application-*"
logName = "projects/my-project/logs/syslog"
```

### By HTTP Status
```
httpRequest.status >= 400
httpRequest.status = 500
```

### By Labels
```
resource.labels.region = "us-central1"
labels.environment = "production"
```

## Cost Optimization

Logging costs can be significant. Use these strategies to optimize:

1. **Filter Unnecessary Logs**: Exclude debug logs in production
2. **Sample High-Volume Logs**: Use `sample(insertId, 0.1)` to sample 10%
3. **Retention Policies**: Set appropriate retention periods
4. **Log Buckets**: Use custom retention buckets for different log types
5. **Monitor Usage**: Regularly review log volume and costs

### Example Cost-Optimized Filter

```hcl
log_filter = <<-EOT
  (
    -- Always include errors
    severity >= ERROR
    OR
    -- Sample 10% of INFO logs
    (severity = INFO AND sample(insertId, 0.1))
  )
  AND NOT (
    -- Exclude high-volume, low-value logs
    httpRequest.requestUrl =~ "/(health|metrics|ready)"
  )
EOT
```

## Requirements

- Terraform >= 1.6
- Google Provider >= 5.30

## Permissions Required

### In Source Project
- `roles/logging.configWriter` - To create log sinks

### In Central Logging Project
- `roles/logging.bucketWriter` - Grant to the sink writer identity

## Setup Steps

1. Create central logging project and bucket
2. Deploy observability module with log sink enabled
3. Grant `roles/logging.bucketWriter` to the sink writer identity in central project:
   ```hcl
   resource "google_project_iam_member" "sink_writer" {
     project = var.central_logging_project
     role    = "roles/logging.bucketWriter"
     member  = module.observability.log_sink_writer_identity
   }
   ```
4. Verify logs are flowing to central bucket

## Notes

- Log sink creates a unique writer identity (service account) automatically
- The writer identity needs `roles/logging.bucketWriter` in the destination project
- Dashboard JSON files must be valid Cloud Monitoring dashboard configurations
- Empty `log_filter` exports all logs (can be expensive)
- Log filters use Cloud Logging query language
