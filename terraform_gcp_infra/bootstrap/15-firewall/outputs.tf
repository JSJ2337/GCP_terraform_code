# =============================================================================
# 15-firewall Outputs
# =============================================================================

output "firewall_rules" {
  description = "생성된 방화벽 규칙 목록"
  value = {
    iap_ssh = {
      name          = google_compute_firewall.allow_iap_ssh.name
      self_link     = google_compute_firewall.allow_iap_ssh.self_link
      target_tags   = google_compute_firewall.allow_iap_ssh.target_tags
      source_ranges = google_compute_firewall.allow_iap_ssh.source_ranges
    }
    jenkins = {
      name          = google_compute_firewall.allow_jenkins.name
      self_link     = google_compute_firewall.allow_jenkins.self_link
      target_tags   = google_compute_firewall.allow_jenkins.target_tags
      source_ranges = google_compute_firewall.allow_jenkins.source_ranges
    }
    bastion_ssh = {
      name          = google_compute_firewall.allow_bastion_ssh.name
      self_link     = google_compute_firewall.allow_bastion_ssh.self_link
      target_tags   = google_compute_firewall.allow_bastion_ssh.target_tags
      source_ranges = google_compute_firewall.allow_bastion_ssh.source_ranges
    }
    internal = {
      name          = google_compute_firewall.allow_internal.name
      self_link     = google_compute_firewall.allow_internal.self_link
      target_tags   = google_compute_firewall.allow_internal.target_tags
      source_ranges = google_compute_firewall.allow_internal.source_ranges
    }
  }
}
