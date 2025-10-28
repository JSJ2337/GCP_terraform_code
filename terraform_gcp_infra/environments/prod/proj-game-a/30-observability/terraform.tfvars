# Observability Configuration
project_id = "proj-game-a-prod"

# Central logging configuration
enable_central_log_sink = true
central_logging_project = "central-logging-prod" # Replace with actual central logging project
central_logging_bucket  = "game-logs-prod"
log_filter              = "resource.type=\"gce_instance\" OR resource.type=\"k8s_container\""

# Dashboard configuration
dashboard_json_files = [
  "dashboards/game-a-compute.json",
  "dashboards/game-a-network.json",
  "dashboards/game-a-application.json"
]