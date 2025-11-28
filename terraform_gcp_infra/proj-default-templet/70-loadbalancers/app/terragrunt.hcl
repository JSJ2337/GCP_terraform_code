include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

dependencies {
  paths = [
    "../../00-project",
    "../../10-network",
    "../../50-workloads"
  ]
}

dependency "workloads" {
  config_path = "../../50-workloads"

  # SKIP_WORKLOADS_DEPENDENCY=true 환경변수 설정 시 outputs 건너뛰기
  skip_outputs = get_env("SKIP_WORKLOADS_DEPENDENCY", "false") == "true"

  mock_outputs = {
    vm_details = {}
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/../..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)

  layer_name = basename(get_terragrunt_dir())
  lb_prefix  = "${local.common_inputs.project_name}-${local.layer_name}"

  layer_backend_service_name   = try(local.layer_inputs.backend_service_name, "")
  layer_url_map_name           = try(local.layer_inputs.url_map_name, "")
  layer_target_http_proxy_name = try(local.layer_inputs.target_http_proxy_name, "")
  layer_forwarding_rule_name   = try(local.layer_inputs.forwarding_rule_name, "")
  layer_static_ip_name         = try(local.layer_inputs.static_ip_name, "")
  layer_health_check_name      = try(local.layer_inputs.health_check_name, "")

  lb_name_defaults = {
    backend_service_name   = length(trimspace(local.layer_backend_service_name)) > 0 ? trimspace(local.layer_backend_service_name) : "${local.lb_prefix}-backend"
    url_map_name           = length(trimspace(local.layer_url_map_name)) > 0 ? trimspace(local.layer_url_map_name) : "${local.lb_prefix}-url-map"
    target_http_proxy_name = length(trimspace(local.layer_target_http_proxy_name)) > 0 ? trimspace(local.layer_target_http_proxy_name) : "${local.lb_prefix}-http-proxy"
    forwarding_rule_name   = length(trimspace(local.layer_forwarding_rule_name)) > 0 ? trimspace(local.layer_forwarding_rule_name) : "${local.lb_prefix}-lb"
    static_ip_name         = length(trimspace(local.layer_static_ip_name)) > 0 ? trimspace(local.layer_static_ip_name) : "${local.lb_prefix}-ip"
    health_check_name      = length(trimspace(local.layer_health_check_name)) > 0 ? trimspace(local.layer_health_check_name) : "${local.lb_prefix}-health"
  }
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  local.lb_name_defaults,
  {
    # 50-workloads에서 VM 정보 가져오기
    vm_details = try(dependency.workloads.outputs.vm_details, {})
  }
)
