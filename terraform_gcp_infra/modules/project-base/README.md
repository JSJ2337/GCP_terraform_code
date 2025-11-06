# 프로젝트 기본 모듈

이 모듈은 필수 서비스, 예산 알림, 로그 보관 정책을 포함한 Google Cloud 프로젝트를 생성하고 구성합니다.

## 기능

- **프로젝트 생성**: 지정한 폴더 또는 조직 아래에 결제 계정이 연결된 GCP 프로젝트 생성
- **삭제 정책**: 프로젝트 삭제 동작 제어 (기본값: 자유롭게 삭제 가능)
- **API 관리**: 필요한 Google Cloud API 활성화
- **예산 알림**: 선택적 예산 모니터링 및 이메일 알림
- **로그 보관**: 프로젝트의 기본 로그 보관 기간 설정
- **CMEK 암호화**: 로그용 고객 관리 암호화 키 (선택사항)
- **레이블**: 조직 및 비용 추적을 위한 사용자 정의 레이블 적용

## 사용법

### 기본 프로젝트

```hcl
module "project" {
  source = "../../modules/project-base"

  project_id      = "my-project-123"
  project_name    = "My Project"
  folder_id       = "folders/123456789012"  # 폴더가 없다면 대신 org_id를 설정
  billing_account = "ABCDEF-123456-GHIJKL"

  labels = {
    environment = "prod"
    team        = "platform"
  }
}
```

### 예산 알림이 있는 프로젝트

```hcl
module "project_with_budget" {
  source = "../../modules/project-base"

  project_id      = "my-project-123"
  project_name    = "My Project"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  # 예산 모니터링 활성화
  enable_budget   = true
  budget_amount   = 1000
  budget_currency = "USD"

  # 사용자 정의 API 목록
  apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com"
  ]

  # 로그 설정
  log_retention_days = 90

  labels = {
    environment = "prod"
    cost_center = "engineering"
  }
}
```

### CMEK 암호화를 사용하는 프로젝트

```hcl
module "secure_project" {
  source = "../../modules/project-base"

  project_id      = "secure-project-123"
  project_name    = "Secure Project"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  # 로그용 고객 관리 암호화
  cmek_key_id = "projects/kms-project/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key"

  log_retention_days = 365

  labels = {
    environment = "prod"
    compliance  = "pci-dss"
  }
}
```

### 삭제 방지가 설정된 중요 프로젝트

```hcl
module "production_project" {
  source = "../../modules/project-base"

  project_id      = "critical-prod-123"
  project_name    = "Critical Production"
  folder_id       = "folders/123456789012"
  billing_account = "ABCDEF-123456-GHIJKL"

  # 실수로 인한 삭제 방지
  deletion_policy = "PREVENT"

  labels = {
    environment = "prod"
    criticality = "high"
  }
}
```

**참고**:
- `deletion_policy = "DELETE"` (기본값): Terraform으로 프로젝트 자유롭게 삭제 가능 (개발/테스트 환경에 권장)
- `deletion_policy = "PREVENT"`: Terraform destroy 시 프로젝트 삭제 차단 (프로덕션/부트스트랩 프로젝트에 권장)
- `deletion_policy = "ABANDON"`: Terraform state에서만 제거, GCP에는 프로젝트 유지

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|------|
| project_id | 생성할 프로젝트 ID | string | - | yes |
| project_name | 프로젝트 표시 이름 | string | "" | no |
| folder_id | 프로젝트를 생성할 폴더 ID (없으면 null) | string | `null` | no |
| org_id | 상위 조직 ID (`folder_id`가 없을 때 필수) | string | `null` | no |
| billing_account | 프로젝트에 연결할 결제 계정 | string | - | yes |
| deletion_policy | 프로젝트 삭제 정책 (DELETE/PREVENT/ABANDON) | string | "DELETE" | no |
| labels | 프로젝트에 적용할 레이블 | map(string) | {} | no |
| apis | 활성화할 API 목록 | list(string) | 아래 참조 | no |
| enable_budget | 예산 모니터링 활성화 | bool | false | no |
| budget_amount | 예산 금액 (지정된 통화 단위) | number | 100 | no |
| budget_currency | 예산 통화 | string | "USD" | no |
| log_retention_days | 기본 로그 보관 기간 (일) | number | 30 | no |
| cmek_key_id | 로그용 고객 관리 암호화 키 | string | "" | no |

> ✅ `folder_id` 또는 `org_id` 중 하나는 반드시 제공해야 합니다. 조직이 있는 환경에서 서비스 계정이 프로젝트를 생성하려면 상위 리소스를 명시해야 합니다.

### 기본 API 목록

모듈은 기본적으로 다음 API를 활성화합니다:
- `compute.googleapis.com` - Compute Engine
- `iam.googleapis.com` - Identity and Access Management
- `servicenetworking.googleapis.com` - Service Networking
- `logging.googleapis.com` - Cloud Logging
- `monitoring.googleapis.com` - Cloud Monitoring
- `cloudkms.googleapis.com` - Cloud Key Management Service

## 출력 값

| 이름 | 설명 |
|------|------|
| project_id | 프로젝트 ID |
| project_number | 프로젝트 번호 |
| project_name | 프로젝트 표시 이름 |

## 모범 사례

1. **폴더 구성**: 환경, 팀 또는 사업부별로 프로젝트를 구성하기 위해 폴더 사용
2. **삭제 정책**:
   - 개발/테스트 환경: `deletion_policy = "DELETE"` (기본값) 사용하여 자유롭게 생성/삭제
   - 프로덕션/중요 인프라: `deletion_policy = "PREVENT"` 설정하여 실수로 인한 삭제 방지
   - 부트스트랩/관리 프로젝트: 반드시 `deletion_policy = "PREVENT"` 사용
3. **예산 알림**: 예상치 못한 비용을 방지하기 위해 프로덕션 프로젝트에 예산 모니터링 활성화
4. **API 관리**: 공격 표면을 줄이기 위해 실제로 필요한 API만 활성화
5. **레이블**: 비용 할당 및 리소스 관리를 위한 일관된 레이블 전략 사용
6. **로그 보관**: 규정 준수 요구사항에 따라 적절한 로그 보관 기간 설정
7. **CMEK**: 민감한 프로젝트에는 고객 관리 암호화 키 사용

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30
- Google Beta Provider >= 5.30 (예산 알림용)

## 필요한 권한

이 모듈을 사용하려면 서비스 계정 또는 사용자에게 다음 권한이 필요합니다:
- 폴더에 대한 `roles/resourcemanager.projectCreator`
- 결제 계정에 대한 `roles/billing.user`
- API 활성화를 위한 `roles/serviceusage.serviceUsageAdmin`

## 참고사항

- 프로젝트는 기본 네트워크 생성을 피하기 위해 `auto_create_network = false`로 생성됩니다
- **삭제 정책**: 기본값은 `DELETE`이므로 terraform destroy로 자유롭게 삭제 가능합니다
  - 중요한 프로젝트는 반드시 `deletion_policy = "PREVENT"` 설정 권장
  - `PREVENT` 설정 시 프로젝트를 삭제하려면 먼저 정책을 `DELETE`로 변경 후 apply 필요
- 예산 알림은 결제 계정 관리자에게 이메일로 전송됩니다
- 로그 보관은 프로젝트 수준에서 구성되며 모든 로그에 적용됩니다
- 로그용 CMEK 암호화는 키가 미리 생성되어 있어야 합니다
