# =============================================================================
# 50-compute Outputs
# =============================================================================

# 전체 인스턴스 정보
output "instances" {
  description = "생성된 VM 인스턴스 정보"
  value = {
    for k, v in google_compute_instance.vm : k => {
      instance_id = v.instance_id
      name        = v.name
      zone        = v.zone
      internal_ip = v.network_interface[0].network_ip
      external_ip = try(v.network_interface[0].access_config[0].nat_ip, null)
      self_link   = v.self_link
    }
  }
}

# SSH 접속 명령어
output "ssh_commands" {
  description = "IAP SSH 접속 명령어"
  value = {
    for k, v in google_compute_instance.vm : k =>
    "gcloud compute ssh ${v.name} --zone=${v.zone} --tunnel-through-iap --project=${var.management_project_id}"
  }
}

# Jenkins 전용 출력
output "jenkins_web_url" {
  description = "Jenkins 웹 UI URL"
  value = try(
    "http://${google_compute_instance.vm["jenkins"].network_interface[0].access_config[0].nat_ip}:8080",
    null
  )
}
