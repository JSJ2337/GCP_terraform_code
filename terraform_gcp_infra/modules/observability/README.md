# 관찰성 모듈

이 모듈은 중앙 집중식 로그 수집 및 사용자 정의 대시보드를 위한 Google Cloud Logging 및 Monitoring을 구성합니다.

## 기능

- **중앙 집중식 로깅**: 프로젝트에서 중앙 로깅 버킷으로 로그 내보내기
- **로그 필터링**: 고급 필터를 사용하여 내보낼 로그 구성
- **고유 작성자 ID**: 로그 싱크용 서비스 계정 자동 생성
- **모니터링 대시보드**: JSON 파일에서 사용자 정의 Cloud Monitoring 대시보드 가져오기
- **다중 대시보드 지원**: 파일 참조에서 여러 대시보드 배포

## 사용법

### 중앙 프로젝트로 기본 로그 싱크

```hcl
module "observability" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  enable_central_log_sink = true
  central_logging_project = "logging-project-456"
  central_logging_bucket  = "central-logs"
}
```

### 사용자 정의 필터가 있는 로그 싱크

```hcl
module "observability_filtered" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  enable_central_log_sink = true
  central_logging_project = "logging-project-456"
  central_logging_bucket  = "central-logs"

  # 오류 및 중요 로그만 내보내기
  log_filter = <<-EOT
    severity >= ERROR
  EOT
}
```

### 모니터링 대시보드만

```hcl
module "observability_dashboards" {
  source = "../../modules/observability"

  project_id = "app-project-123"

  enable_central_log_sink = false

  dashboard_json_files = [
    "${path.module}/dashboards/app-metrics.json",
    "${path.module}/dashboards/infrastructure.json"
  ]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | 프로젝트 ID | `string` | n/a | yes |
| enable_central_log_sink | 중앙 로그 싱크 활성화 | `bool` | `false` | no |
| central_logging_project | 중앙 로깅 프로젝트 ID | `string` | `""` | no |
| central_logging_bucket | 중앙 로깅 버킷 이름 | `string` | `""` | no |
| log_filter | 로그 필터 표현식 | `string` | `""` | no |
| dashboard_json_files | 대시보드 JSON 파일 경로 목록 | `list(string)` | `[]` | no |

## 출력 값

| 이름 | 설명 |
|------|------|
| log_sink_writer_identity | 로그 싱크 작성자 서비스 계정 |
| log_sink_id | 로그 싱크 ID |
| dashboard_ids | 생성된 대시보드 ID 목록 |

## 로그 필터 예제

### 심각도별
```
severity >= ERROR                    # 오류 및 중요 로그만
severity = WARNING                   # 경고 로그만
```

### 리소스 타입별
```
resource.type = "gce_instance"       # VM 인스턴스 로그
resource.type = "gcs_bucket"         # GCS 버킷 로그
```

### 로그 이름별
```
logName:"cloudaudit.googleapis.com"  # 감사 로그
logName:"compute.googleapis.com"     # Compute Engine 로그
```

## 모범 사례

1. **중앙 집중식 로깅**: 여러 프로젝트의 로그를 단일 프로젝트로 집계
2. **필터 사용**: 비용 절감을 위해 필요한 로그만 내보내기
3. **보존 정책**: 규정 준수 요구사항에 따라 적절한 보존 기간 설정
4. **대시보드**: 주요 메트릭 및 KPI 시각화
5. **알림**: 비정상 조건에 대한 알림 정책 설정

## 보안 고려사항

1. **액세스 제어**: 중앙 로깅 버킷에 대한 액세스 제한
2. **작성자 권한**: 로그 싱크 작성자 ID에 대상 버킷에 대한 권한 부여
3. **민감한 데이터**: 로그에서 민감한 정보 제거 또는 마스킹
4. **감사**: 로깅 구성 변경사항 추적

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30

## 필요한 권한

- `roles/logging.configWriter` - 로그 싱크 생성
- `roles/monitoring.dashboardEditor` - 대시보드 생성
- 대상 프로젝트에서: `roles/logging.bucketWriter` - 로그 버킷에 쓰기

## 참고사항

- 로그 싱크는 고유한 서비스 계정(작성자 ID)을 생성합니다
- 이 서비스 계정에 대상 로깅 버킷에 쓸 수 있는 권한을 부여해야 합니다
- 대시보드는 JSON 형식이어야 하며 Cloud Monitoring에서 내보낼 수 있습니다
- 로그 내보내기는 거의 실시간이지만 약간의 지연이 있을 수 있습니다
