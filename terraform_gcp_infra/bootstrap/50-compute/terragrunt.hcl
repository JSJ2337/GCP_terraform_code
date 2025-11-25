# =============================================================================
# 50-compute Terragrunt Configuration
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  parent_dir = abspath("${get_terragrunt_dir()}/..")

  # 공통 입력 읽기 (HCL 파일 직접 파싱)
  common_vars = read_terragrunt_config("${local.parent_dir}/common.hcl")

  # 레이어 입력 읽기
  layer_vars = read_terragrunt_config("${get_terragrunt_dir()}/layer.hcl")
}

# 00-foundation 의존성 (실행 순서 보장용)
dependency "foundation" {
  config_path = "../00-foundation"
  skip_outputs = true
}

# 10-network 의존성 (실행 순서 보장용)
dependency "network" {
  config_path = "../10-network"
  skip_outputs = true
}

# 의존성 순서
dependencies {
  paths = ["../00-foundation", "../10-network", "../20-storage"]
}

# common.hcl에서 직접 값을 가져옴 (dependency output 대신)
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {}
)
