# 프로젝트 기본 모듈

이 모듈은 필수 서비스, 예산 알림, 로그 보관 정책을 포함한 Google Cloud 프로젝트를 생성하고 구성합니다.

## 기능

- **프로젝트 생성**: 폴더 내에 결제 계정이 연결된 GCP 프로젝트 생성
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
  folder_id       = "folders/123456789012"
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

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|------|
| project_id | 생성할 프로젝트 ID | string | - | yes |
| project_name | 프로젝트 표시 이름 | string | "" | no |
| folder_id | 프로젝트를 생성할 폴더 ID | string | - | yes |
| billing_account | 프로젝트에 연결할 결제 계정 | string | - | yes |
| labels | 프로젝트에 적용할 레이블 | map(string) | {} | no |
| apis | 활성화할 API 목록 | list(string) | 아래 참조 | no |
| enable_budget | 예산 모니터링 활성화 | bool | false | no |
| budget_amount | 예산 금액 (지정된 통화 단위) | number | 100 | no |
| budget_currency | 예산 통화 | string | "USD" | no |
| log_retention_days | 기본 로그 보관 기간 (일) | number | 30 | no |
| cmek_key_id | 로그용 고객 관리 암호화 키 | string | "" | no |

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
2. **예산 알림**: 예상치 못한 비용을 방지하기 위해 프로덕션 프로젝트에 예산 모니터링 활성화
3. **API 관리**: 공격 표면을 줄이기 위해 실제로 필요한 API만 활성화
4. **레이블**: 비용 할당 및 리소스 관리를 위한 일관된 레이블 전략 사용
5. **로그 보관**: 규정 준수 요구사항에 따라 적절한 로그 보관 기간 설정
6. **CMEK**: 민감한 프로젝트에는 고객 관리 암호화 키 사용

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
- 예산 알림은 결제 계정 관리자에게 이메일로 전송됩니다
- 로그 보관은 프로젝트 수준에서 구성되며 모든 로그에 적용됩니다
- 로그용 CMEK 암호화는 키가 미리 생성되어 있어야 합니다
