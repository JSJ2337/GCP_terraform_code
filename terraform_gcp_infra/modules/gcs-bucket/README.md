# GCS 버킷 모듈

이 모듈은 포괄적인 구성 옵션을 가진 단일 Google Cloud Storage 버킷을 생성하고 관리합니다.

## 기능

- **보안**: 버킷 수준의 통합 액세스, 공개 액세스 방지, CMEK 암호화
- **수명 주기 관리**: 자동화된 객체 수명 주기 규칙
- **버전 관리**: 선택적 객체 버전 관리
- **액세스 로깅**: 선택적 액세스 로그 생성
- **CORS**: 교차 출처 리소스 공유 구성
- **IAM**: 조건부 바인딩을 사용한 세밀한 액세스 제어
- **알림**: 버킷 이벤트에 대한 Pub/Sub 알림
- **보관 정책**: 버킷 수준 보관 정책

## 사용법

### 기본 버킷

```hcl
module "simple_bucket" {
  source = "../../modules/gcs-bucket"

  project_id  = "my-project-id"
  bucket_name = "my-simple-bucket"
  location    = "US"
}
```

### 수명 주기 및 버전 관리가 있는 고급 버킷

```hcl
module "versioned_bucket" {
  source = "../../modules/gcs-bucket"

  project_id                  = "my-project-id"
  bucket_name                 = "my-versioned-bucket"
  location                    = "US-CENTRAL1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  enable_versioning           = true

  labels = {
    environment = "prod"
    purpose     = "assets"
  }

  lifecycle_rules = [
    {
      condition = {
        num_newer_versions = 3
      }
      action = {
        type = "Delete"
      }
    },
    {
      condition = {
        age = 365
      }
      action = {
        type          = "SetStorageClass"
        storage_class = "ARCHIVE"
      }
    }
  ]

  kms_key_name = "projects/my-project/locations/us-central1/keyRings/my-ring/cryptoKeys/my-key"
}
```

### IAM 및 CORS가 있는 버킷

```hcl
module "public_assets_bucket" {
  source = "../../modules/gcs-bucket"

  project_id  = "my-project-id"
  bucket_name = "my-public-assets"
  location    = "US"

  cors_rules = [
    {
      origin          = ["https://example.com", "https://www.example.com"]
      method          = ["GET", "HEAD"]
      response_header = ["Content-Type"]
      max_age_seconds = 3600
    }
  ]

  iam_bindings = [
    {
      role    = "roles/storage.objectViewer"
      members = ["allUsers"]
    }
  ]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | 프로젝트 ID | `string` | n/a | yes |
| bucket_name | 버킷 이름 (전역적으로 고유해야 함) | `string` | n/a | yes |
| location | 버킷 위치 | `string` | `"US"` | no |
| storage_class | 스토리지 클래스 | `string` | `"STANDARD"` | no |
| force_destroy | 객체가 있는 버킷 삭제 허용 | `bool` | `false` | no |
| uniform_bucket_level_access | 버킷 수준의 통합 액세스 활성화 | `bool` | `true` | no |
| labels | 적용할 레이블 | `map(string)` | `{}` | no |
| enable_versioning | 객체 버전 관리 활성화 | `bool` | `false` | no |
| lifecycle_rules | 수명 주기 관리 규칙 | `list(object)` | `[]` | no |
| retention_policy_days | 보관 정책 (일) | `number` | `0` | no |
| kms_key_name | 암호화용 KMS 키 | `string` | `""` | no |
| cors_rules | CORS 구성 | `list(object)` | `[]` | no |
| public_access_prevention | 공개 액세스 방지 | `string` | `"enforced"` | no |
| iam_bindings | IAM 역할 바인딩 | `list(object)` | `[]` | no |
| notifications | Pub/Sub 알림 | `list(object)` | `[]` | no |

> ℹ️ Terragrunt에서 선택 입력을 생략하거나 `null`을 전달해도 안전합니다. 모듈이 기본값(예: `retention_policy_days = 0`, `public_access_prevention = "enforced"`)을 적용하도록 보완되어 있습니다.

## 출력 값

| 이름 | 설명 |
|------|------|
| bucket_name | 생성된 버킷 이름 |
| bucket_url | 버킷 URL |
| bucket_self_link | 버킷 셀프 링크 |
| bucket_location | 버킷 위치 |
| bucket_storage_class | 버킷 스토리지 클래스 |

## 보안 고려사항

1. **버킷 수준의 통합 액세스**: 간소화된 IAM 관리를 위해 기본적으로 활성화
2. **공개 액세스 방지**: 실수로 인한 공개 노출을 방지하기 위해 기본적으로 "enforced"로 설정
3. **IAM 바인딩**: 충돌을 방지하기 위해 `google_storage_bucket_iam_member` (비권한적) 사용
4. **CMEK**: 저장 데이터 암호화를 위한 고객 관리 암호화 키 지원

## 모범 사례

1. 항상 전역적으로 고유한 버킷 이름 사용
2. 중요한 데이터에 대해 버전 관리 활성화
3. 스토리지 비용 최적화를 위한 수명 주기 규칙 구성
4. 민감한 데이터에 CMEK 사용
5. 비용 추적을 위한 일관된 레이블링 적용
6. 규정 준수를 위한 적절한 보관 정책 설정
