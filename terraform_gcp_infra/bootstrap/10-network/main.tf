# =============================================================================
# 10-network: 관리용 네트워크 인프라 (VPC, Subnet, Router, NAT)
# Firewall 규칙은 15-firewall 레이어로 분리됨
# =============================================================================

# =============================================================================
# Remote State Data Sources (Cross-Project)
# =============================================================================
# 서로 다른 Jenkins Job에서 실행되는 프로젝트의 outputs를 GCS State에서 직접 읽음
# Best Practice: dependency 블록 대신 terraform_remote_state 사용
#
# 새 프로젝트 추가 시:
#   1. common.hcl의 projects에 프로젝트 정보 추가
#   2. 아래에 data source 블록 추가 (database, cache)
#   3. locals의 {project}_psc_endpoints 추가
#   4. psc_endpoints merge에 추가

# gcby 프로젝트 - 60-database
data "terraform_remote_state" "gcby_database" {
  count   = var.enable_psc_endpoints && contains(keys(var.projects), "gcby") ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.projects.gcby.project_id}/60-database"
  }
}

# gcby 프로젝트 - 65-cache
data "terraform_remote_state" "gcby_cache" {
  count   = var.enable_psc_endpoints && contains(keys(var.projects), "gcby") ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.projects.gcby.project_id}/65-cache"
  }
}

# web3 프로젝트 - 60-database
data "terraform_remote_state" "web3_database" {
  count   = var.enable_psc_endpoints && contains(keys(var.projects), "web3") ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.projects.web3.project_id}/60-database"
  }
}

# web3 프로젝트 - 65-cache
data "terraform_remote_state" "web3_cache" {
  count   = var.enable_psc_endpoints && contains(keys(var.projects), "web3") ? 1 : 0
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.projects.web3.project_id}/65-cache"
  }
}

# 새 프로젝트 추가 예시 (주석)
# data "terraform_remote_state" "abc_database" {
#   count   = var.enable_psc_endpoints && contains(keys(var.projects), "abc") ? 1 : 0
#   backend = "gcs"
#   config = {
#     bucket = var.state_bucket
#     prefix = "${var.projects.abc.project_id}/60-database"
#   }
# }

locals {
  network_name = "${var.management_project_id}-vpc"
  subnet_name  = "${var.management_project_id}-subnet"

  # VPC Peering 대상 목록 (terragrunt.hcl에서 전달됨)
  # 형식: { project_key = "projects/{id}/global/networks/{name}" }
  project_vpc_peerings = var.project_vpc_network_urls

  # Primary가 아닌 리전 (게임 프로젝트용 - us-west1)
  # subnets에서 is_primary = false인 첫 번째 항목의 region 사용
  non_primary_subnets = { for k, v in var.subnets : k => v if !v.is_primary }
  psc_region = length(local.non_primary_subnets) > 0 ? values(local.non_primary_subnets)[0].region : var.region_primary

  # ==========================================================================
  # PSC Endpoints 동적 생성 (terraform_remote_state에서 Service Attachment 참조)
  # ==========================================================================

  # gcby 프로젝트 PSC Endpoints
  # 프로젝트명, 환경명 모두 common.hcl의 projects에서 가져옴
  gcby_project_name = try(split("-", var.projects.gcby.project_id)[1], "gcby")  # gcp-gcby → gcby
  gcby_env = try(var.projects.gcby.environment, "live")
  gcby_redis_service_attachments = var.enable_psc_endpoints && contains(keys(var.projects), "gcby") ? try(
    data.terraform_remote_state.gcby_cache[0].outputs.psc_service_attachment_links, []
  ) : []

  gcby_psc_endpoints = var.enable_psc_endpoints && contains(keys(var.projects), "gcby") ? merge(
    # Cloud SQL PSC Endpoint (1개)
    {
      "${local.gcby_project_name}-${local.gcby_env}-gdb-m1" = {
        region                    = local.psc_region
        ip_address                = try(var.projects.gcby.psc_ips.cloudsql, "")
        target_service_attachment = try(data.terraform_remote_state.gcby_database[0].outputs.psc_service_attachment_link, "")
        allow_global_access       = true
      }
    },
    # Redis PSC Endpoints (2개 - Discovery + Shard)
    {
      for idx, sa in local.gcby_redis_service_attachments :
      "${local.gcby_project_name}-${local.gcby_env}-redis-${idx}" => {
        region                    = local.psc_region
        ip_address                = try(var.projects.gcby.psc_ips.redis[idx], "")
        target_service_attachment = sa
        allow_global_access       = true
      }
    }
  ) : {}

  # web3 프로젝트 PSC Endpoints
  web3_project_name = try(split("-", var.projects.web3.project_id)[1], "web3")  # gcp-web3 → web3
  web3_env = try(var.projects.web3.environment, "live")
  web3_redis_service_attachments = var.enable_psc_endpoints && contains(keys(var.projects), "web3") ? try(
    data.terraform_remote_state.web3_cache[0].outputs.psc_service_attachment_links, []
  ) : []

  web3_psc_endpoints = var.enable_psc_endpoints && contains(keys(var.projects), "web3") ? merge(
    # Cloud SQL PSC Endpoint (1개)
    {
      "${local.web3_project_name}-${local.web3_env}-gdb-m1" = {
        region                    = local.psc_region
        ip_address                = try(var.projects.web3.psc_ips.cloudsql, "")
        target_service_attachment = try(data.terraform_remote_state.web3_database[0].outputs.psc_service_attachment_link, "")
        allow_global_access       = true
      }
    },
    # Redis PSC Endpoints (2개 - Discovery + Shard)
    {
      for idx, sa in local.web3_redis_service_attachments :
      "${local.web3_project_name}-${local.web3_env}-redis-${idx}" => {
        region                    = local.psc_region
        ip_address                = try(var.projects.web3.psc_ips.redis[idx], "")
        target_service_attachment = sa
        allow_global_access       = true
      }
    }
  ) : {}

  # 새 프로젝트 추가 예시 (주석)
  # abc_project_name = try(split("-", var.projects.abc.project_id)[1], "abc")
  # abc_env = try(var.projects.abc.environment, "live")
  # abc_redis_service_attachments = var.enable_psc_endpoints && contains(keys(var.projects), "abc") ? try(
  #   data.terraform_remote_state.abc_cache[0].outputs.psc_service_attachment_links, []
  # ) : []
  # abc_psc_endpoints = var.enable_psc_endpoints && contains(keys(var.projects), "abc") ? merge(
  #   {
  #     "${local.abc_project_name}-${local.abc_env}-gdb-m1" = {
  #       region                    = "us-west1"
  #       ip_address                = try(var.projects.abc.psc_ips.cloudsql, "")
  #       target_service_attachment = try(data.terraform_remote_state.abc_database[0].outputs.psc_service_attachment_link, "")
  #       allow_global_access       = true
  #     }
  #   },
  #   {
  #     for idx, sa in local.abc_redis_service_attachments :
  #     "${local.abc_project_name}-${local.abc_env}-redis-${idx}" => {
  #       region                    = "us-west1"
  #       ip_address                = try(var.projects.abc.psc_ips.redis[idx], "")
  #       target_service_attachment = sa
  #       allow_global_access       = true
  #     }
  #   }
  # ) : {}

  # 모든 프로젝트 PSC Endpoints 병합
  psc_endpoints = merge(
    local.gcby_psc_endpoints,
    local.web3_psc_endpoints,
    # local.abc_psc_endpoints,
  )
}

# -----------------------------------------------------------------------------
# 1) VPC 네트워크
# -----------------------------------------------------------------------------
resource "google_compute_network" "mgmt_vpc" {
  project                 = var.management_project_id
  name                    = local.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "Management VPC for Jenkins and shared services"
}

# -----------------------------------------------------------------------------
# 2) Subnets (for_each로 동적 생성)
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "mgmt_subnets" {
  for_each = var.subnets

  project       = var.management_project_id
  name          = each.value.is_primary ? local.subnet_name : "${var.management_project_id}-subnet-${each.value.region}"
  ip_cidr_range = each.value.cidr
  region        = each.value.region
  network       = google_compute_network.mgmt_vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# 3) Cloud Routers (NAT용, 리전별 - for_each로 동적 생성)
# -----------------------------------------------------------------------------
resource "google_compute_router" "mgmt_routers" {
  for_each = var.subnets

  project = var.management_project_id
  name    = each.value.is_primary ? "${var.management_project_id}-router" : "${var.management_project_id}-router-${each.value.region}"
  region  = each.value.region
  network = google_compute_network.mgmt_vpc.id

  bgp {
    # Primary는 64514, 그 외는 64515부터 순차 증가
    asn = each.value.is_primary ? 64514 : 64515
  }
}

# -----------------------------------------------------------------------------
# 4) Cloud NATs (리전별 - for_each로 동적 생성)
# -----------------------------------------------------------------------------
resource "google_compute_router_nat" "mgmt_nats" {
  for_each = var.subnets

  project = var.management_project_id
  name    = each.value.is_primary ? "${var.management_project_id}-nat" : "${var.management_project_id}-nat-${each.value.region}"
  router  = google_compute_router.mgmt_routers[each.key].name
  region  = each.value.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}

# -----------------------------------------------------------------------------
# 5) VPC Peering to project VPCs (for DNS resolution and private connectivity)
# -----------------------------------------------------------------------------
# 동적으로 모든 프로젝트 VPC와 Peering 생성
# 새 프로젝트 추가 시: bootstrap/common.hcl의 projects에 추가하면 자동 반영
resource "google_compute_network_peering" "mgmt_to_projects" {
  for_each = local.project_vpc_peerings

  name         = "peering-mgmt-to-${each.key}"
  network      = google_compute_network.mgmt_vpc.self_link
  peer_network = each.value

  import_custom_routes = true
  export_custom_routes = true
}

# -----------------------------------------------------------------------------
# 6) PSC Endpoints for Cloud SQL (mgmt VPC용)
# -----------------------------------------------------------------------------
# Internal IP 주소 예약 (PSC Endpoint용)
resource "google_compute_address" "psc_addresses" {
  for_each = local.psc_endpoints

  project      = var.management_project_id
  name         = "${each.key}-psc"
  region       = each.value.region
  # 해당 리전의 subnet 찾기 (region으로 매칭)
  subnetwork   = [for k, v in google_compute_subnetwork.mgmt_subnets : v.id if v.region == each.value.region][0]
  address_type = "INTERNAL"
  address      = each.value.ip_address
  purpose      = "GCE_ENDPOINT"

  # Address가 forwarding rule에서 사용 중일 때 변경 방지
  # 변경이 필요한 경우 먼저 forwarding rule 삭제 후 진행해야 함
  lifecycle {
    ignore_changes = [subnetwork]
  }
}

# PSC Forwarding Rule
resource "google_compute_forwarding_rule" "psc_endpoints" {
  for_each = local.psc_endpoints

  project               = var.management_project_id
  name                  = "${each.key}-psc-fr"
  region                = each.value.region
  network               = google_compute_network.mgmt_vpc.id
  ip_address            = google_compute_address.psc_addresses[each.key].id
  load_balancing_scheme = ""
  target                = each.value.target_service_attachment

  # Cross-region access 활성화 (Global Access)
  allow_psc_global_access = each.value.allow_global_access
}

