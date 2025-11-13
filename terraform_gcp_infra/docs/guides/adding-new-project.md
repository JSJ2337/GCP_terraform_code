# Quick Setup Guide (proj-default-templet 템플릿 기반 신규 프로젝트)

이 문서는 `terraform_gcp_infra/proj-default-templet/` 템플릿을 복제하여 새 환경을 빠르게 구성하기 위한 체크리스트입니다.

---

## 1. 준비 사항
- **새 프로젝트 코드**: 예) `proj-myservice-prod`
- **GCP Project ID / Billing Account**: 실제 배포 대상
- **Remote State 버킷/Prefix**: 중앙 상태 버킷(`delabs-terraform-state-prod`) 재사용, Prefix는 신규 환경명으로 변경
- **Notification Channel ID**: Cloud Monitoring 알림 채널(이메일·Slack 등) 사전 생성

---

## 2. 디렉터리 복제
```bash
cd terraform_gcp_infra
cp -R proj-default-templet environments/LIVE/proj-myservice-prod
```

---

## 3. 공통 설정 업데이트
| 파일 | 수정 항목 |
|------|-----------|
| `environments/LIVE/proj-myservice-prod/root.hcl` | **필수**: `project_state_prefix`, `remote_state_project`, `remote_state_location` 설정 확인 |
| `environments/LIVE/proj-myservice-prod/common.naming.tfvars` | `project_id`, `project_name`, `environment`, `organization`, `region_*` 값을 신규 환경에 맞게 설정 |
| Terragrunt `inputs` | 필요 시 `folder_product`, `folder_region`, `folder_env` 입력을 정의해 bootstrap 폴더 조합을 선택 |
| `environments/LIVE/proj-myservice-prod/root.hcl` | 루트 `inputs`에 공통 값(`org_id`, `billing_account` 등) 설정 |

**⚠️ root.hcl 필수 설정**:
```hcl
locals {
  remote_state_bucket   = "jsj-terraform-state-prod"
  remote_state_project  = "jsj-system-mgmt"
  remote_state_location = "US"
  project_state_prefix  = "proj-myservice-prod"    # 환경별로 변경
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket   = local.remote_state_bucket
    project  = local.remote_state_project
    location = local.remote_state_location
    prefix   = "${local.project_state_prefix}/${path_relative_to_include()}"
  }
  # 버킷이 이미 존재하므로 생성 건너뛰기
  skip_bucket_creation      = true
  skip_bucket_versioning    = true
  skip_bucket_accesslogging = true
}
```

- Terragrunt가 위 `generate` 설정으로 각 레이어에 `backend.tf`를 자동 생성합니다. 별도의 backend 파일을 커밋하거나 수동으로 관리할 필요가 없습니다.

---

## Terragrunt & Naming 구조 개요
- 각 레이어의 `terragrunt.hcl`은 `common.naming.tfvars`와 레이어 전용 `terraform.tfvars`를 자동 병합해 Terraform에 전달합니다.
- `common.naming.tfvars`에 적은 값(예: `project_id`, `region_primary`)은 naming 모듈을 통해 공통 리소스 이름·라벨·기본 존(`region_primary` + suffix)을 계산합니다.
- 레이어의 `terraform.tfvars`에 값이 비어 있으면 Terragrunt가 루트 `inputs` 값을 주입하고, 필요한 경우에만 해당 파일에서 재정의하면 됩니다.
- 프로젝트마다 리전을 바꾸고 싶다면 해당 환경의 `common.naming.tfvars`에서 `region_primary`/`region_backup`만 수정하면 되고, naming 모듈이 자동으로 존까지 계산합니다.
- 특정 레이어에서 다른 리전·존을 써야 한다면 그 레이어 `terraform.tfvars`에 직접 값을 넣어 Terragrunt 입력을 덮어쓰면 됩니다.


---

## 4. 레이어별 필수 값
| 레이어 | 필수 수정 항목 | 파일 |
|--------|----------------|------|
| 00-project | `folder_id`, `billing_account`, 필요 API, 라벨 | `terraform.tfvars` |
| 10-network | VPC CIDR, Secondary 범위, Firewall 규칙 | `terraform.tfvars` |
| 20-storage | 버킷 위치/Storage Class, KMS 키, IAM | `terraform.tfvars` |
| 30-security | IAM 바인딩, 서비스 계정 생성 토글 | `terraform.tfvars` |
| 40-observability | `notification_channels`, 필요 시 Alert 임계값/정규식 | `terraform.tfvars` |
| 50-workloads | VM 갯수/머신타입/시작 스크립트, 네트워크 태그 | `terraform.tfvars` |
| 60-database | Cloud SQL Tier/지역/백업/로그 정책 | `terraform.tfvars` |
| 65-cache | Memorystore 메모리, 대체 존, 유지보수 창 | `terraform.tfvars` |
| 70-loadbalancers/* | 서비스별 Load Balancer 설정 (예: lobby, web) | 각 하위 디렉터리의 `terraform.tfvars` |

> ⚠️ Load Balancer 디렉터리가 여러 개일 경우, 각 `terraform.tfvars`에서 `backend_service_name`, `url_map_name`, `forwarding_rule_name`, `static_ip_name` 등을 서로 다른 값으로 지정해 이름 충돌을 방지하세요.

> 모든 레이어는 `terraform.tfvars.example`를 복사한 뒤 필수 항목을 채우면 됩니다.

---

## 5. Jenkinsfile 복사 및 설정 (CI/CD 사용 시)

### 5.1. Jenkinsfile 템플릿 복사
```bash
# Jenkinsfile 템플릿 복사
cp .jenkins/Jenkinsfile.template environments/LIVE/proj-myservice-prod/Jenkinsfile
```

### 5.2. TG_WORKING_DIR 수정 (⚠️ 필수)
```bash
# Jenkinsfile 편집
vim environments/LIVE/proj-myservice-prod/Jenkinsfile

# TG_WORKING_DIR을 실제 프로젝트 경로로 변경:
# TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/proj-myservice-prod'
```

**⚠️ 중요**:
- `TG_WORKING_DIR`은 workspace root 기준 **절대 경로** 사용
- `.` (상대 경로)를 사용하면 템플릿 디렉터리까지 실행됨
- Jenkins Pipeline은 항상 workspace root에서 시작

### 5.3. Jenkins Job 생성
```
Jenkins → New Item → Pipeline

Configuration:
  - Pipeline script from SCM
  - SCM: Git
  - Repository URL: <your-git-repo>
  - Script Path: terraform_gcp_infra/environments/LIVE/proj-myservice-prod/Jenkinsfile
```

### 5.4. GCP Credential 설정
Jenkins에 GCP Service Account Key 등록 (최초 1회):
```
Jenkins → Manage Jenkins → Credentials → Add Credentials
  - Kind: Secret file
  - File: jenkins-sa-key.json (bootstrap에서 생성)
  - ID: gcp-jenkins-service-account  ⚠️ 정확히 이 ID로 입력
  - Description: GCP Service Account for Jenkins
```

> 상세 내용은 `00_README.md`의 "GCP 인증 설정 (Jenkins용)" 섹션 참조

---

## 6. Terragrunt 실행 순서
```bash
cd environments/LIVE/proj-myservice-prod
# 레이어별 배포 (예시)
terragrunt run --all init
terragrunt run --all plan
terragrunt run --queue-include-dir '00-project' --all apply -- -auto-approve   # 00-project
terragrunt run --queue-include-dir '10-network' --all apply -- -auto-approve  # 10-network
# 이후 20 → 30 → ... → 70 순서로 동일하게 실행
```

> Terragrunt 0.93 이상에서는 `run --all` 명령을 사용합니다. 특정 레이어만 실행하려면 `--queue-include-dir '<레이어 디렉터리>'`로 큐를 필터링하거나, 필요 시 `terragrunt -chdir=<layer> plan/apply` 형태로 단일 레이어를 직접 실행할 수도 있습니다.

---

## 7. 마무리 체크
- [ ] Cloud Monitoring Alert 정책이 새 프로젝트에서 정상 생성되었는지 확인
- [ ] 중앙 로그 싱크 사용 시 대상 버킷에 `log_sink_writer_identity` 서비스 계정 권한 부여
- [ ] Terraform/Terragrunt 상태 버킷에 새로운 Prefix가 생성되었는지 확인
- [ ] README/작업 내역(CHANGELOG 등)에 신규 환경 추가 기록

필요 시 `04_WORK_HISTORY.md`에 신규 배포 이력을 남기고, 후속 자동화(CI/CD, tfsec 등)를 연동해주세요.

---

## Bootstrap state 공유 메모
- bootstrap은 local backend를 사용합니다. `terraform_gcp_infra/bootstrap/terraform.tfstate`를 안전한 곳에 백업하고, 파이프라인/다른 엔지니어가 `data "terraform_remote_state"`로 읽을 수 있도록 GCS 복사본을 유지하세요.
  ```bash
  cd terraform_gcp_infra/bootstrap
  terraform apply
  gsutil cp terraform.tfstate gs://jsj-terraform-state-prod/bootstrap/default.tfstate
  ```
- 환경 코드에서는 아래와 같이 GCS backend로 bootstrap state를 조회합니다.
  ```hcl
  data "terraform_remote_state" "bootstrap" {
    backend = "gcs"
    config = {
      bucket = "jsj-terraform-state-prod"
      prefix = "bootstrap"
    }
  }
  ```
