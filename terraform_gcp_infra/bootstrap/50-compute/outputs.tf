# =============================================================================
# 50-compute Outputs
# =============================================================================

# Jenkins VM 정보
output "jenkins_instance_id" {
  description = "Jenkins VM 인스턴스 ID"
  value       = google_compute_instance.jenkins.instance_id
}

output "jenkins_instance_name" {
  description = "Jenkins VM 인스턴스 이름"
  value       = google_compute_instance.jenkins.name
}

output "jenkins_self_link" {
  description = "Jenkins VM Self Link"
  value       = google_compute_instance.jenkins.self_link
}

output "jenkins_internal_ip" {
  description = "Jenkins VM 내부 IP"
  value       = google_compute_instance.jenkins.network_interface[0].network_ip
}

output "jenkins_external_ip" {
  description = "Jenkins VM 외부 IP"
  value       = var.assign_external_ip ? google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip : null
}

output "jenkins_zone" {
  description = "Jenkins VM 존"
  value       = google_compute_instance.jenkins.zone
}

# 고정 IP (생성한 경우)
output "jenkins_static_ip" {
  description = "Jenkins 고정 외부 IP"
  value       = var.create_static_ip ? google_compute_address.jenkins_ip[0].address : null
}

# 접속 정보
output "jenkins_ssh_command" {
  description = "Jenkins VM SSH 접속 명령어 (IAP)"
  value       = "gcloud compute ssh ${google_compute_instance.jenkins.name} --zone=${google_compute_instance.jenkins.zone} --tunnel-through-iap --project=${var.management_project_id}"
}

output "jenkins_web_url" {
  description = "Jenkins 웹 UI URL"
  value       = var.assign_external_ip ? "http://${google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip}:8080" : "http://${google_compute_instance.jenkins.network_interface[0].network_ip}:8080"
}
