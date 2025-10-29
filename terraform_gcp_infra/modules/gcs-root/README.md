# GCS 루트 모듈

이 모듈은 공통 기본 설정을 사용하여 여러 Google Cloud Storage 버킷을 관리합니다.

## 목적

`gcs-root` 모듈은 `gcs-bucket` 모듈의 래퍼로, 다음과 같은 기능으로 여러 GCS 버킷을 생성하고 관리할 수 있습니다:
- 공유 기본 레이블
- 공통 KMS 암호화 키
- 통합 공개 액세스 방지 설정
- 개별 버킷별 구성

## 사용법

```hcl
module "storage" {
  source = "../../modules/gcs-root"

  project_id                      = "my-project-id"
  default_labels                  = {
    environment = "prod"
    managed_by  = "terraform"
  }
  default_kms_key_name            = "projects/my-project/locations/us/keyRings/my-ring/cryptoKeys/my-key"
  default_public_access_prevention = "enforced"

  buckets = {
    assets = {
      name          = "my-assets-bucket"
      location      = "US-CENTRAL1"
      storage_class = "STANDARD"
      enable_versioning = true
      cors_rules = [{
        origin = ["https://example.com"]
        method = ["GET"]
      }]
    }
    logs = {
      name              = "my-logs-bucket"
      storage_class     = "COLDLINE"
      retention_policy_days = 90
    }
  }
}
```

## 기능

- **DRY 구성**: 모든 버킷에 대한 공통 설정을 한 번만 정의
- **유연한 재정의**: 각 버킷이 기본 설정을 재정의 가능
- **일관된 레이블링**: 조직 전체 레이블 자동 적용
- **기본 보안**: 버킷 수준의 통합 액세스 및 공개 액세스 방지 강제

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | 버킷을 생성할 프로젝트 ID | `string` | n/a | yes |
| buckets | 버킷 구성 맵 | `map(object)` | n/a | yes |
| default_labels | 모든 버킷에 적용할 기본 레이블 | `map(string)` | `{}` | no |
| default_kms_key_name | 버킷 암호화용 기본 KMS 키 이름 | `string` | `""` | no |
| default_public_access_prevention | 기본 공개 액세스 방지 설정 | `string` | `"enforced"` | no |

## 출력 값

| 이름 | 설명 |
|------|------|
| bucket_names | 버킷 키에서 버킷 이름으로의 맵 |
| bucket_urls | 버킷 키에서 버킷 URL로의 맵 |
| bucket_self_links | 버킷 키에서 버킷 셀프 링크로의 맵 |
| bucket_locations | 버킷 키에서 버킷 위치로의 맵 |
| bucket_storage_classes | 버킷 키에서 스토리지 클래스로의 맵 |

## 이 모듈을 사용해야 하는 경우

다음의 경우 `gcs-root` 사용:
- 유사한 구성을 가진 여러 버킷을 생성해야 할 때
- 일관된 레이블링 및 보안 설정을 강제하고 싶을 때
- 버킷 암호화 키의 중앙 집중식 관리가 필요할 때

다음의 경우 `gcs-bucket` 직접 사용:
- 단일 버킷만 필요할 때
- 각 버킷이 완전히 다른 구성을 가질 때
