output "log_sink_writer_identity" {
  value       = try(google_logging_project_sink.to_central[0].writer_identity, null)
  description = "중앙 버킷에 이 SA에 대한 권한을 부여해야 함"
}
