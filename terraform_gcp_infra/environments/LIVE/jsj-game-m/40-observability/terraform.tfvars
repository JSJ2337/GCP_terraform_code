# Region Configuration
# Uncomment to override the default region from common.naming.tfvars.
# region = "asia-northeast3"

# Observability Configuration

# Central logging configuration (disabled for now)
enable_central_log_sink = false
central_logging_project = ""
central_logging_bucket  = ""
log_filter              = ""

# Dashboard configuration (empty for now)
dashboard_json_files = []

# Alert notification channels (수동 생성된 채널 ID 목록)
notification_channels = []

# Slack Notifications (자동 생성)
#enable_slack_notifications    = true
#slack_webhook_secret_name     = "slack-webhook-url"
#slack_webhook_secret_project  = "jsj-system-mgmt"  # Secret이 저장된 프로젝트
#slack_channel_name            = "#game-alerts"
#slack_channel_display_name    = "Game-M Alerts"

# VM CPU Alert
enable_vm_cpu_alert       = true
vm_cpu_threshold          = 0.85  # 85% CPU 사용 시 알림
vm_cpu_duration           = "300s"  # 5분 지속 시
#vm_instance_filter_regex  = "^jsj-game-m-.*"  # jsj-game-m으로 시작하는 모든 VM

# Cloud SQL CPU Alert
enable_cloudsql_cpu_alert  = true
cloudsql_cpu_threshold     = 0.75  # 75% CPU 사용 시 알림
cloudsql_cpu_duration      = "600s"  # 10분 지속 시
cloudsql_instance_regex    = "^jsj-game-m:asia-northeast3:jsj-game-m-mysql$"

# Redis Memory Alert
enable_memorystore_memory_alert = true
memorystore_memory_threshold    = 0.80  # 80% 메모리 사용 시 알림
memorystore_memory_duration     = "300s"  # 5분 지속 시
memorystore_instance_regex      = "^projects/jsj-game-m/locations/asia-northeast3/instances/jsj-game-m-redis$"

# Load Balancer 5xx Error Alert
enable_lb_5xx_alert        = true
lb_5xx_threshold           = 10  # 분당 10개 이상의 5xx 에러 시 알림
lb_5xx_duration            = "300s"  # 5분 지속 시
lb_target_proxy_regex      = "^jsj-game-m-.*-(http|https)-proxy$"  # jsj-game-m LB proxy
