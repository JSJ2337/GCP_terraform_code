# ============================================================================
# Network Layer Outputs
# ============================================================================
# 다른 레이어(특히 50-workloads)에서 서브넷 정보를 참조할 수 있도록 구조화된 출력 제공

output "subnets" {
  description = "Map of subnet types to their detailed information including self_link, region, project_id, and name"
  value = {
    dmz = {
      self_link  = local.dmz_subnet_self_link
      region     = local.dmz_subnet != null ? local.dmz_subnet.region : null
      project_id = var.project_id
      name       = local.dmz_subnet_name
    }
    private = {
      self_link  = local.private_subnet_self_link
      region     = local.private_subnet != null ? local.private_subnet.region : null
      project_id = var.project_id
      name       = local.private_subnet_name
    }
    db = {
      self_link  = local.db_subnet_self_link
      region     = local.db_subnet != null ? local.db_subnet.region : null
      project_id = var.project_id
      name       = local.db_subnet_name
    }
  }
}

output "vpc_self_link" {
  description = "The self_link of the VPC network"
  value       = module.net.vpc_self_link
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = module.naming.vpc_name
}
