# 신규 프로젝트 추가 가이드

proj-default-templet 템플릿을 기반으로 새 환경을 빠르게 구성하는 가이드입니다.

## 빠른 시작

### 1. 준비 사항

- **새 프로젝트 코드**: 예) `jsj-game-m`
- **GCP Project ID**: 실제 배포 대상
- **Billing Account**: `01076D-327AD5-FC8922`
- **Remote State 버킷**: `jsj-terraform-state-prod` (기존 재사용)

### 2. 템플릿 복사

```bash
cd terraform_gcp_infra
cp -R proj-default-templet environments/LIVE/jsj-game-m
```

### 3. 환경 설정 업데이트

#### root.hcl 수정

```bash
vim environments/LIVE/jsj-game-m/root.hcl
```

```hcl
locals {
  remote_state_bucket   = "jsj-terraform-state-prod"
  remote_state_project  = "jsj-system-mgmt"
  remote_state_location = "US"
  project_state_prefix  = "jsj-game-m"    # ⚠️ 환경별로 변경
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
  skip_bucket_creation = true
}

inputs = {
  org_id          = ""
  billing_account = "01076D-327AD5-FC8922"
  region_primary  = "asia-northeast3"
  region_backup   = "asia-northeast1"
}
```

#### common.naming.tfvars 수정

```bash
vim environments/LIVE/jsj-game-m/common.naming.tfvars
```

```hcl
project_id     = "jsj-game-m"      # ⚠️ GCP 프로젝트 ID
project_name   = "game-m"          # ⚠️ 프로젝트 이름
environment    = "prod"
organization   = "433"
region_primary = "asia-northeast3"
region_backup  = "asia-northeast1"
```

## Phase 기반 배포 (권장)

### Jenkins 사용

1. **Jenkinsfile 복사 및 수정**

```bash
cp proj-default-templet/Jenkinsfile environments/LIVE/jsj-game-m/Jenkinsfile

vim environments/LIVE/jsj-game-m/Jenkinsfile
# TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/jsj-game-m'
```

2. **Jenkins Job 생성**

```text
Jenkins → New Item → Pipeline
- Name: terraform-jsj-game-m
- Pipeline script from SCM
- Script Path: terraform_gcp_infra/environments/LIVE/jsj-game-m/Jenkinsfile
```

3. **배포 실행**

```text
Parameters:
- TARGET_LAYER: all
- ACTION: apply
- ENABLE_OBSERVABILITY: true
```

**실행 순서:**
1. 모든 Phase Plan (Phase 1-8 순차)
2. 전체 승인 (한 번만)
3. 각 Phase Re-plan + Apply (순차)

### 수동 배포 (Phase 기반)

```bash
cd environments/LIVE/jsj-game-m

# Phase 1: Project Setup
terragrunt run --all --queue-include-dir 00-project -- apply

# Phase 2: Network
terragrunt run --all --queue-include-dir 10-network -- apply

# Phase 3: Storage & Security
terragrunt run --all \
  --queue-include-dir 20-storage \
  --queue-include-dir 30-security \
  -- apply

# Phase 4: Observability (Optional)
terragrunt run --all --queue-include-dir 40-observability -- apply

# Phase 5: Workloads
terragrunt run --all --queue-include-dir 50-workloads -- apply

# Phase 6: Database & Cache
terragrunt run --all \
  --queue-include-dir 60-database \
  --queue-include-dir 65-cache \
  -- apply

# Phase 7: Load Balancers
terragrunt run --all --queue-include-dir 70-loadbalancers -- apply

# Phase 8: DNS
terragrunt run --all --queue-include-dir 75-dns -- apply
```

## 자동화 기능

### 1. subnet_type 자동 매핑

50-workloads에서 subnet_type만 지정하면 자동 매핑:

```hcl
# 50-workloads/terraform.tfvars
instances = {
  "web-01" = {
    subnet_type = "dmz"    # 자동으로 10-network outputs 참조
    machine_type = "e2-medium"
  }
}
```

### 2. GCS Location 자동화

region_primary 기반 자동 생성 (수동 설정 불필요):
- assets/logs 버킷: Same-region
- backups 버킷: Multi-region (DR)

### 3. 네이밍 자동화

project_name 기반 모든 리소스명 자동 생성:
- VPC: `{project_name}-vpc`
- Subnet: `{project_name}-subnet-{type}`
- Backend: `{project_name}-{service}-backend`

## 레이어별 필수 설정

| 레이어 | 필수 수정 항목 | 파일 |
|--------|----------------|------|
| 00-project | folder_id, billing_account, APIs | terraform.tfvars |
| 10-network | VPC CIDR, Subnet 범위 | terraform.tfvars |
| 20-storage | (자동 생성, 수정 불필요) | - |
| 30-security | IAM 바인딩 | terraform.tfvars |
| 40-observability | notification_channels | terraform.tfvars |
| 50-workloads | VM 개수/타입, subnet_type | terraform.tfvars |
| 60-database | Cloud SQL Tier, 백업 정책 | terraform.tfvars |
| 65-cache | Memorystore 메모리 크기 | terraform.tfvars |
| 70-loadbalancers | Backend 필터링 패턴 | terraform.tfvars |
| 75-dns | DNS Zone, 레코드 | terraform.tfvars |

## 마무리 체크리스트

- [ ] root.hcl의 project_state_prefix 변경 확인
- [ ] common.naming.tfvars의 project_id, project_name 변경 확인
- [ ] Jenkinsfile의 TG_WORKING_DIR 변경 확인
- [ ] Jenkins Job 생성 및 GCP Credential 연결
- [ ] Phase 1 (00-project) 배포 성공 확인
- [ ] Phase 2-8 순차 배포
- [ ] Cloud Monitoring Alert 정책 생성 확인
- [ ] State 버킷에 새 prefix 생성 확인

## Jenkins vs 수동 배포 비교

| 항목 | Jenkins (권장) | 수동 배포 |
|------|---------------|-----------|
| 승인 | 1회 (전체) | Phase별 |
| Re-plan | 자동 | 수동 |
| 에러 처리 | 자동 중단 | 수동 확인 |
| 로깅 | 중앙화 | 분산 |
| 배포 시간 | 45-70분 | 동일 |
| 권장 상황 | 프로덕션, 전체 배포 | 개발, 부분 배포 |

## 참고 자료

- [Jenkins CI/CD 가이드](./jenkins-cicd.md) - Phase 기반 배포 상세
- [Terragrunt 사용법](./terragrunt-usage.md) - Terragrunt 0.93+ 구문
- [트러블슈팅](../troubleshooting/common-errors.md) - 일반적인 오류 해결

---

**Last Updated: 2025-11-21**
**Version: Phase-Based v2.0**
