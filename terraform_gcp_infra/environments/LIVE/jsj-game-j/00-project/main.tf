terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30"
    }
  }

}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Bootstrap에서 폴더 구조 정보 가져오기
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "../../../../bootstrap/terraform.tfstate"
  }
}

module "naming" {
  source         = "../../../../modules/naming"
  project_name   = var.project_name != "" ? var.project_name : var.project_id
  environment    = var.environment
  organization   = var.organization
  region_primary = var.region_primary
  region_backup  = var.region_backup
}

module "project_base" {
  source = "../../../../modules/project-base"

  project_id      = var.project_id
  project_name    = var.project_name != "" ? var.project_name : module.naming.project_name
  folder_id       = data.terraform_remote_state.bootstrap.outputs.folder_structure["games"]["kr-region"]["LIVE"]
  org_id          = null # 폴더 사용 시 org_id는 null
  billing_account = var.billing_account
  labels          = merge(module.naming.common_labels, var.labels)

  apis               = var.apis
  enable_budget      = var.enable_budget
  budget_amount      = var.budget_amount
  budget_currency    = var.budget_currency
  log_retention_days = var.log_retention_days
  cmek_key_id        = var.cmek_key_id
}
