terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
  }
}

locals {
  alternative_location_id = length(trimspace(var.alternative_location_id)) > 0 ? trimspace(var.alternative_location_id) : ""
  maintenance_enabled     = var.maintenance_window_day != "" && var.maintenance_window_start_hour != null && var.maintenance_window_start_minute != null
  is_enterprise_tier      = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.tier)
  split_region            = split("-", var.region)
  enterprise_region       = length(local.split_region) > 2 ? join("-", slice(local.split_region, 0, length(local.split_region) - 1)) : var.region
}

resource "google_redis_instance" "standard" {
  count = local.is_enterprise_tier ? 0 : 1

  project = var.project_id
  name    = var.instance_name

  tier                    = var.tier
  memory_size_gb          = var.memory_size_gb
  redis_version           = var.redis_version
  location_id             = var.region
  connect_mode            = var.connect_mode
  labels                  = var.labels
  authorized_network      = var.authorized_network
  transit_encryption_mode = var.transit_encryption_mode

  display_name = length(trimspace(var.display_name)) > 0 ? var.display_name : null

  alternative_location_id = length(local.alternative_location_id) > 0 ? local.alternative_location_id : null

  dynamic "maintenance_policy" {
    for_each = local.maintenance_enabled ? [1] : []
    content {
      weekly_maintenance_window {
        day = var.maintenance_window_day
        start_time {
          hours   = var.maintenance_window_start_hour
          minutes = var.maintenance_window_start_minute
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.tier != "STANDARD_HA" || length(local.alternative_location_id) > 0
      error_message = "STANDARD_HA tier requires alternative_location_id (e.g., us-central1-b)."
    }

    precondition {
      condition     = local.is_enterprise_tier || (var.replica_count == null && var.shard_count == null)
      error_message = "replica_count or shard_count can only be set for ENTERPRISE/ENTERPRISE_PLUS tiers."
    }
  }
}

resource "google_redis_cluster" "enterprise" {
  count = local.is_enterprise_tier ? 1 : 0

  project = var.project_id
  name    = var.instance_name
  region  = local.enterprise_region

  shard_count             = var.shard_count
  replica_count           = var.replica_count
  authorization_mode      = var.enterprise_authorization_mode
  transit_encryption_mode = var.enterprise_transit_encryption_mode
  node_type               = var.enterprise_node_type

  deletion_protection_enabled = var.deletion_protection

  redis_configs = var.enterprise_redis_configs

  psc_configs {
    network = var.authorized_network
  }

  dynamic "maintenance_policy" {
    for_each = local.maintenance_enabled ? [1] : []
    content {
      weekly_maintenance_window {
        day = upper(var.maintenance_window_day)
        start_time {
          hours   = var.maintenance_window_start_hour
          minutes = var.maintenance_window_start_minute
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.replica_count != null && var.replica_count >= 1
      error_message = "Enterprise tiers require replica_count to be set to 1 or greater."
    }

    precondition {
      condition     = var.shard_count != null && var.shard_count >= 1
      error_message = "Enterprise tiers require shard_count to be set to 1 or greater."
    }
  }
}

# =============================================================================
# Cross-Project PSC Connections (User Created)
# =============================================================================
# 다른 프로젝트/VPC에서 이 Redis Cluster에 PSC로 접근하려면
# 해당 VPC의 PSC Forwarding Rule을 이 클러스터에 등록해야 함
#
# 참고: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_cluster_user_created_connections
#
# 중요: google_redis_cluster_user_created_connections 리소스를 사용하면
# 클러스터의 모든 PSC 연결을 명시적으로 관리해야 합니다.
# 이 방식 대신 gcloud CLI나 API를 통한 점진적 추가가 더 안전할 수 있습니다.
#
# 현재는 cross_project_psc_connections 변수로 연결 정보만 전달받고,
# 실제 등록은 bootstrap에서 PSC Forwarding Rule 생성 시 자동으로 시도됩니다.
# 만약 자동 등록이 PENDING 상태로 남으면, 수동으로 gcloud 명령 실행 필요:
#
# gcloud redis clusters update <CLUSTER_NAME> \
#   --region=<REGION> \
#   --project=<PROJECT_ID> \
#   --add-cross-cluster-replication-clusters=...

# Cross-project PSC 연결 정보를 outputs로 노출하여
# 필요시 외부에서 등록할 수 있도록 함
locals {
  cross_project_psc_info = [
    for conn in var.cross_project_psc_connections : {
      project_id = conn.project_id
      network    = conn.network
      forwarding_rules = [
        for idx, fr in conn.forwarding_rules : {
          psc_connection_id  = fr.psc_connection_id
          name               = fr.name
          ip_address         = fr.ip_address
          region             = fr.region
          service_attachment = try(google_redis_cluster.enterprise[0].psc_service_attachments[idx].service_attachment, "")
        }
      ]
    }
  ]
}
