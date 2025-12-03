# 12-dns 레이어 설정

locals {
  # common.hcl 읽기 (projects 정보 참조용)
  parent_dir  = abspath("${get_terragrunt_dir()}/..")
  common_vars = read_terragrunt_config("${local.parent_dir}/common.hcl")
  projects    = local.common_vars.locals.projects

  # DNS Zone 설정
  dns_zone_name = "delabsgames-internal"
  dns_domain    = "delabsgames.internal."

  # ==========================================================================
  # DNS 레코드 동적 생성
  # ==========================================================================
  # 1) mgmt 프로젝트 고정 VM (수동 관리)
  mgmt_vm_records = {
    "jenkins" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.10.7"]
    }
    "bastion" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.250.10.6"]
    }
  }

  # 2) 각 프로젝트의 VM 레코드 (동적 생성)
  # 형식: {project_key}-{vm_name} = { A, 300, [IP] }
  project_vm_records = merge([
    for project_key, project in local.projects : {
      for vm_name, vm_ip in project.vm_ips :
      "${project_key}-${vm_name}" => {
        type    = "A"
        ttl     = 300
        rrdatas = [vm_ip]
      }
    }
  ]...)

  # 3) 각 프로젝트의 PSC Endpoint 레코드 (동적 생성)
  # 형식: {project_key}-{env}-gdb-m1 = { A, 300, [PSC_IP] }
  project_psc_records = merge([
    for project_key, project in local.projects : {
      # Cloud SQL PSC endpoint
      "${project_key}-${project.environment}-gdb-m1" = {
        type    = "A"
        ttl     = 300
        rrdatas = [project.psc_ips.cloudsql]
      }
      # Redis PSC endpoint (첫 번째 IP = Discovery endpoint)
      "${project_key}-${project.environment}-redis" = {
        type    = "A"
        ttl     = 300
        rrdatas = [project.psc_ips.redis[0]]
      }
    }
  ]...)

  # 모든 DNS 레코드 병합
  dns_records = merge(
    local.mgmt_vm_records,
    local.project_vm_records,
    local.project_psc_records,
    # 추가 레코드가 필요하면 여기에 추가
    # {
    #   "gitlab" = {
    #     type    = "A"
    #     ttl     = 300
    #     rrdatas = ["10.250.10.5"]
    #   }
    # }
  )
}
