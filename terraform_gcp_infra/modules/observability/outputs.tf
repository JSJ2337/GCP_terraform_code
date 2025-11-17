output "log_sink_writer_identity" {
  value       = try(google_logging_project_sink.to_central[0].writer_identity, null)
  description = "중앙 버킷에 이 SA에 대한 권한을 부여해야 함"
}

output "slack_notification_channel_id" {
  value       = try(google_monitoring_notification_channel.slack[0].id, null)
  description = "생성된 Slack Notification Channel ID"
}

output "slack_notification_channel_name" {
  value       = try(google_monitoring_notification_channel.slack[0].name, null)
  description = "생성된 Slack Notification Channel 리소스 이름"
}

output "all_notification_channels" {
  value       = local.all_notification_channels
  description = "Alert Policy에 연결된 모든 Notification Channel 목록"
}
