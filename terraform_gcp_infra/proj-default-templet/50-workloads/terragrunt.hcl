include "root" {
  path = find_in_parent_folders("root.hcl")
}


# terraform.source를 제거하여 in-place 실행
# 이렇게 하면 .terragrunt-cache 없이 현재 디렉토리에서 직접 실행됩니다

locals {
  parent_dir        = abspath("${get_terragrunt_dir()}/..")
  raw_common_inputs = read_tfvars_file("${local.parent_dir}/common.naming.tfvars")
  common_inputs     = try(jsondecode(local.raw_common_inputs), local.raw_common_inputs)

  raw_layer_inputs = try(read_tfvars_file("${get_terragrunt_dir()}/terraform.tfvars"), tomap({}))
  layer_inputs     = try(jsondecode(local.raw_layer_inputs), local.raw_layer_inputs)
}

# 네트워크 레이어 의존성 설정
dependency "network" {
  config_path = "../10-network"

  # 10-network가 아직 apply되지 않았을 때 사용할 mock 데이터
  mock_outputs = {
    subnets = {
      dmz = {
        self_link  = "mock-dmz-subnet"
        region     = "asia-northeast3"
        project_id = "mock-project"
        name       = "mock-dmz"
      }
      private = {
        self_link  = "mock-private-subnet"
        region     = "asia-northeast3"
        project_id = "mock-project"
        name       = "mock-private"
      }
      db = {
        self_link  = "mock-db-subnet"
        region     = "asia-northeast3"
        project_id = "mock-project"
        name       = "mock-db"
      }
    }
    vpc_self_link = "mock-vpc-self-link"
    vpc_name      = "mock-vpc-name"
  }

  # 10-network가 apply되지 않았어도 plan은 가능하도록 설정
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # 네트워크 레이어에서 서브넷 정보 가져오기
    subnets = dependency.network.outputs.subnets
  }
)

dependencies {
  paths = [
    "../00-project",
    "../10-network",
    "../30-security"
  ]
}
