# =============================================================================
# 10-network Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = google_compute_network.mgmt_vpc.id
}

output "vpc_name" {
  description = "VPC 이름"
  value       = google_compute_network.mgmt_vpc.name
}

output "vpc_self_link" {
  description = "VPC Self Link"
  value       = google_compute_network.mgmt_vpc.self_link
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.mgmt_subnet.id
}

output "subnet_name" {
  description = "Subnet 이름"
  value       = google_compute_subnetwork.mgmt_subnet.name
}

output "subnet_self_link" {
  description = "Subnet Self Link"
  value       = google_compute_subnetwork.mgmt_subnet.self_link
}

output "subnet_cidr" {
  description = "Subnet CIDR"
  value       = google_compute_subnetwork.mgmt_subnet.ip_cidr_range
}

output "router_name" {
  description = "Cloud Router 이름"
  value       = google_compute_router.mgmt_router.name
}

output "nat_name" {
  description = "Cloud NAT 이름"
  value       = google_compute_router_nat.mgmt_nat.name
}

# Secondary region subnet outputs (게임 프로젝트 리전용)
output "subnet_secondary_id" {
  description = "Secondary region Subnet ID"
  value       = google_compute_subnetwork.mgmt_subnet_secondary.id
}

output "subnet_secondary_name" {
  description = "Secondary region Subnet 이름"
  value       = google_compute_subnetwork.mgmt_subnet_secondary.name
}

output "subnet_secondary_self_link" {
  description = "Secondary region Subnet Self Link"
  value       = google_compute_subnetwork.mgmt_subnet_secondary.self_link
}

# =============================================================================
# PSC Endpoints Outputs (for cross-project registration)
# =============================================================================
output "psc_forwarding_rules" {
  description = "PSC Forwarding Rules 정보 (cross-project PSC 연결 등록용)"
  value = {
    for key, fr in google_compute_forwarding_rule.psc_endpoints : key => {
      name              = fr.name
      region            = fr.region
      ip_address        = fr.ip_address
      psc_connection_id = fr.psc_connection_id
      self_link         = fr.self_link
    }
  }
}

output "psc_redis_forwarding_rules" {
  description = "Redis PSC Forwarding Rules (for google_redis_cluster_user_created_connections)"
  value = [
    for key, fr in google_compute_forwarding_rule.psc_endpoints : {
      psc_connection_id = fr.psc_connection_id
      forwarding_rule   = fr.id  # Full URL: projects/{project}/regions/{region}/forwardingRules/{name}
      ip_address        = fr.ip_address
    } if startswith(key, "gcby-redis-")
  ]
}
