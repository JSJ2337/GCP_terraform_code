# IAM 모듈

이 모듈은 프로젝트 수준의 Google Cloud IAM 바인딩을 관리하고 선택적으로 서비스 계정을 생성합니다.

## 기능

- **IAM 바인딩**: 프로젝트 수준 IAM 역할에 멤버 추가 (비권한적)
- **서비스 계정**: 서비스 계정 생성 및 관리
- **비권한적**: 기존 바인딩에 영향을 주지 않고 권한을 안전하게 추가하기 위해 `google_project_iam_member` 사용
- **유연한 구성**: 사용자, 그룹 및 서비스 계정 지원

## 사용법

### 기본 IAM 바인딩

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id = "my-project-id"

  bindings = [
    {
      role   = "roles/compute.viewer"
      member = "user:alice@example.com"
    },
    {
      role   = "roles/storage.admin"
      member = "group:platform-team@example.com"
    },
    {
      role   = "roles/logging.viewer"
      member = "serviceAccount:app@my-project.iam.gserviceaccount.com"
    }
  ]
}
```

### IAM 바인딩과 함께 서비스 계정 생성

```hcl
module "iam_with_sa" {
  source = "../../modules/iam"

  project_id = "my-project-id"

  # 서비스 계정 생성
  create_service_accounts = true

  service_accounts = [
    {
      account_id   = "app-backend"
      display_name = "Backend Application Service Account"
      description  = "Service account for backend API"
    },
    {
      account_id   = "data-pipeline"
      display_name = "Data Pipeline Service Account"
      description  = "Service account for ETL jobs"
    }
  ]

  # 서비스 계정 및 사용자에게 권한 부여
  bindings = [
    {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:app-backend@my-project.iam.gserviceaccount.com"
    },
    {
      role   = "roles/bigquery.dataEditor"
      member = "serviceAccount:data-pipeline@my-project.iam.gserviceaccount.com"
    },
    {
      role   = "roles/iam.serviceAccountUser"
      member = "user:developer@example.com"
    }
  ]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | 프로젝트 ID | `string` | n/a | yes |
| bindings | IAM 바인딩 목록 | `list(object)` | `[]` | no |
| create_service_accounts | 서비스 계정 생성 여부 | `bool` | `false` | no |
| service_accounts | 생성할 서비스 계정 목록 | `list(object)` | `[]` | no |

### 바인딩 객체 구조

```hcl
{
  role   = string              # 필수: IAM 역할 (예: "roles/viewer")
  member = string              # 필수: 멤버 (예: "user:alice@example.com")
}
```

### 서비스 계정 객체 구조

```hcl
{
  account_id   = string        # 필수: 서비스 계정 ID
  display_name = string        # 선택: 표시 이름
  description  = string        # 선택: 설명
}
```

## 출력 값

| 이름 | 설명 |
|------|------|
| service_account_emails | 생성된 서비스 계정 이메일 목록 |
| service_account_ids | 생성된 서비스 계정 ID 목록 |

## 보안 고려사항

1. **비권한적 바인딩**: `google_project_iam_member`를 사용하여 기존 바인딩과 충돌 방지
2. **최소 권한 원칙**: 필요한 최소한의 권한만 부여
3. **서비스 계정**: 애플리케이션마다 별도의 서비스 계정 사용
4. **감사**: IAM 변경사항은 Cloud Audit Logs에 기록됨

## 모범 사례

1. **역할 분리**: 업무에 따라 적절한 역할 사용
2. **그룹 사용**: 개별 사용자 대신 그룹에 권한 부여
3. **서비스 계정 명명**: 명확하고 설명적인 이름 사용
4. **정기 검토**: IAM 바인딩을 정기적으로 검토하고 불필요한 권한 제거
5. **문서화**: 각 바인딩의 목적을 주석으로 문서화

## 일반적인 IAM 역할

### 컴퓨팅 관련
- `roles/compute.viewer` - Compute Engine 리소스 읽기 전용
- `roles/compute.admin` - Compute Engine 전체 관리

### 스토리지 관련
- `roles/storage.objectViewer` - 객체 읽기
- `roles/storage.objectCreator` - 객체 생성
- `roles/storage.objectAdmin` - 객체 전체 관리

### 네트워킹 관련
- `roles/compute.networkViewer` - 네트워크 리소스 읽기
- `roles/compute.networkAdmin` - 네트워크 전체 관리

### 모니터링 관련
- `roles/logging.viewer` - 로그 읽기
- `roles/monitoring.metricWriter` - 메트릭 작성

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30

## 필요한 권한

- `roles/resourcemanager.projectIamAdmin` - IAM 바인딩 관리
- `roles/iam.serviceAccountAdmin` - 서비스 계정 생성 및 관리

## 참고사항

- 이 모듈은 비권한적 방식으로 IAM 바인딩을 추가합니다 (기존 바인딩을 제거하지 않음)
- 서비스 계정 이메일은 `{account_id}@{project_id}.iam.gserviceaccount.com` 형식입니다
- IAM 변경사항이 전파되는데 최대 7분이 걸릴 수 있습니다
- 민감한 역할 부여 시 특히 주의하세요 (예: `roles/owner`, `roles/editor`)
