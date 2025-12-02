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

# us-west1 subnet outputs
output "subnet_us_west1_id" {
  description = "us-west1 Subnet ID"
  value       = google_compute_subnetwork.mgmt_subnet_us_west1.id
}

output "subnet_us_west1_name" {
  description = "us-west1 Subnet 이름"
  value       = google_compute_subnetwork.mgmt_subnet_us_west1.name
}

output "subnet_us_west1_self_link" {
  description = "us-west1 Subnet Self Link"
  value       = google_compute_subnetwork.mgmt_subnet_us_west1.self_link
}
