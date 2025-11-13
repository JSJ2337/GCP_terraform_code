# 00-project 레이어
> Terragrunt: environments/LIVE/jsj-game-m/00-project/terragrunt.hcl


Terraform/Terragrunt 구성을 통해 GCP 프로젝트 생성과 기본 설정(API 활성화, 라벨, 예산 경보 등)을 담당합니다. 이후 모든 레이어는 이 프로젝트를 기반으로 리소스를 생성합니다.

## 주요 기능
- GCP 프로젝트 생성 및 Billing Account 연결
- 필수 API 활성화 (`compute`, `iam`, `servicenetworking`, `logging`, `monitoring`, `cloudkms`, `storage`, `cloudresourcemanager`)
- 공통 라벨/태그 주입 (modules/naming과 병합)
- (선택) 예산 알림 설정 및 로그 보존 기간 지정

## 입력 값 준비
1. `terraform.tfvars.example` 파일을 복사합니다.
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 아래 항목을 환경에 맞게 수정하세요.
   - `project_id`, `project_name`
   - `folder_id` (있는 경우) 또는 `org_id` (조직 최상위에 생성 시 필수)
   - `billing_account`
   - 라벨(`labels`) 및 API 목록(`apis`)
   - 예산 설정(`enable_budget`, `budget_amount`, `budget_currency`)
   - 로그 보존 기간(`log_retention_days`)
   - CMEK를 사용할 경우 `cmek_key_id`

> Terragrunt 루트(`proj-default-templet/root.hcl`)의 `inputs` 섹션에 `org_id`, `billing_account` 등을 설정하면 모든 레이어에서 자동으로 사용됩니다.

> ⚠️ `terraform.tfvars` 파일은 Git에 커밋하면 안 됩니다.

## Terragrunt 실행 절차
```bash
cd environments/prod/proj-default-templet/00-project
terragrunt init        --non-interactive
terragrunt plan        --non-interactive
terragrunt apply       --non-interactive
```

## 참고 사항
- Bootstrap 프로젝트(state 버킷)가 이미 배포되어 있어야 합니다.
- Application Default Credentials의 quota project를 bootstrap 프로젝트로 설정했는지 확인하세요. (예: `gcloud auth application-default set-quota-project jsj-system-mgmt`)
