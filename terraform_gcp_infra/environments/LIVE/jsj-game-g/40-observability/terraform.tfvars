# Region Configuration
region = ""

# Observability Configuration

# Central logging configuration (disabled for now)
enable_central_log_sink = false
central_logging_project = ""
central_logging_bucket  = ""
log_filter              = ""

# Dashboard configuration (empty for now)
dashboard_json_files = []

# Alert notification channels (e.g., projects/<project>/notificationChannels/<id>)
notification_channels = []

# Alert tuning (defaults are production-friendly; override when needed)
# vm_instance_regex = "^default-templet-prod-vm-\\d+$"
# cloudsql_instance_regex = "^my-project:us-central1:default-templet-prod-mysql$"
# memorystore_instance_regex = "^projects/my-project/locations/us-central1/instances/default-templet-prod-redis$"
# lb_target_proxy_regex = "^default-templet-prod-lb-(http|https)-proxy$"
