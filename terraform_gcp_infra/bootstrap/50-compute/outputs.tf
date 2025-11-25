# =============================================================================
# 50-compute Outputs
# =============================================================================

locals {
  # role=ci-cd 라벨을 가진 Jenkins 인스턴스 찾기
  jenkins_instances = {
    for k, v in google_compute_instance.vm : k => v
    if try(v.labels["role"], "") == "ci-cd"
  }
  jenkins_key = length(keys(local.jenkins_instances)) > 0 ? keys(local.jenkins_instances)[0] : null
}

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

# Jenkins 전용 출력 (role=ci-cd 라벨로 동적 탐색)
output "jenkins_web_url" {
  description = "Jenkins 웹 UI URL"
  value = local.jenkins_key != null ? try(
    "http://${local.jenkins_instances[local.jenkins_key].network_interface[0].access_config[0].nat_ip}:8080",
    null
  ) : null
}
