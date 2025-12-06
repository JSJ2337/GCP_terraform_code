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

# =============================================================================
# Subnets (for_each 기반 - 모든 subnet 정보)
# =============================================================================
output "subnets" {
  description = "모든 Subnet 정보"
  value = {
    for k, v in google_compute_subnetwork.mgmt_subnets : k => {
      id        = v.id
      name      = v.name
      self_link = v.self_link
      cidr      = v.ip_cidr_range
      region    = v.region
    }
  }
}

# 하위 호환성을 위한 Primary subnet outputs
output "subnet_id" {
  description = "Primary Subnet ID"
  value       = google_compute_subnetwork.mgmt_subnets["primary"].id
}

output "subnet_name" {
  description = "Primary Subnet 이름"
  value       = google_compute_subnetwork.mgmt_subnets["primary"].name
}

output "subnet_self_link" {
  description = "Primary Subnet Self Link"
  value       = google_compute_subnetwork.mgmt_subnets["primary"].self_link
}

output "subnet_cidr" {
  description = "Primary Subnet CIDR"
  value       = google_compute_subnetwork.mgmt_subnets["primary"].ip_cidr_range
}

# =============================================================================
# Routers & NATs (for_each 기반)
# =============================================================================
output "routers" {
  description = "모든 Cloud Router 정보"
  value = {
    for k, v in google_compute_router.mgmt_routers : k => {
      name   = v.name
      region = v.region
    }
  }
}

output "nats" {
  description = "모든 Cloud NAT 정보"
  value = {
    for k, v in google_compute_router_nat.mgmt_nats : k => {
      name   = v.name
      region = v.region
    }
  }
}

# 하위 호환성을 위한 Primary router/nat outputs
output "router_name" {
  description = "Primary Cloud Router 이름"
  value       = google_compute_router.mgmt_routers["primary"].name
}

output "nat_name" {
  description = "Primary Cloud NAT 이름"
  value       = google_compute_router_nat.mgmt_nats["primary"].name
}

# 하위 호환성을 위한 Secondary region subnet outputs
output "subnet_secondary_id" {
  description = "Secondary region Subnet ID (us-west1)"
  value       = google_compute_subnetwork.mgmt_subnets["us-west1"].id
}

output "subnet_secondary_name" {
  description = "Secondary region Subnet 이름 (us-west1)"
  value       = google_compute_subnetwork.mgmt_subnets["us-west1"].name
}

output "subnet_secondary_self_link" {
  description = "Secondary region Subnet Self Link (us-west1)"
  value       = google_compute_subnetwork.mgmt_subnets["us-west1"].self_link
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
      psc_connection_id  = fr.psc_connection_id
      forwarding_rule    = fr.id  # Full URL: projects/{project}/regions/{region}/forwardingRules/{name}
      ip_address         = fr.ip_address
      name               = fr.name
      region             = fr.region
      service_attachment = fr.target  # PSC가 연결된 service attachment
    } if can(regex("-redis-\\d+$", key))  # {project}-{env}-redis-0, {project}-{env}-redis-1 등 매칭
  ]
}
