# 40-observability 레이어
> Terragrunt: environments/LIVE/jsj-game-m/40-observability/terragrunt.hcl


Cloud Logging 싱크 및 Cloud Monitoring 대시보드/알림 구성을 담당하는 레이어입니다. 조직의 중앙 로그 프로젝트와 연동하거나, 환경별 관찰성 정책을 적용할 때 사용합니다.

## 주요 기능
- Cloud Logging BigQuery/GCS 싱크 생성 (옵션)
- 모듈에서 제공하는 모니터링 대시보드 JSON을 배포
- GCE VM / Cloud SQL / Memorystore / HTTPS LB 에 대한 기본 Alert 정책 생성

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 주요 항목 설명:
   - `enable_central_log_sink`: 중앙 로그 프로젝트로 싱크를 만들 경우 `true`
   - `central_logging_project`, `central_logging_bucket`: 싱크 대상 프로젝트/버킷
   - `log_filter`: 싱크 대상 로그 필터 (예: 특정 리소스 타입 또는 심각도)
   - `dashboard_json_files`: Cloud Monitoring 대시보드 JSON 파일 경로 리스트
   - `notification_channels`: Alert 정책에 연결할 채널 ID 목록
   - `enable_*_alert`, `*_threshold`, `*_duration`: 각 리소스별 Alert 임계값과 지속 시간
   - `*_regex`: naming 모듈 기본값 외의 커스텀 리소스 명칭을 모니터링할 때 재정의

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/40-observability
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- 대시보드 JSON 파일은 저장소 내 별도 디렉터리에 보관하고 상대 경로로 지정하세요.
- 중앙 로그 싱크를 생성하는 경우 대상 프로젝트에서 충분한 권한(Logging Admin 등)을 갖추었는지 확인하세요.
- Alert 정책은 naming 모듈이 생성하는 기본 자원 이름을 기준으로 필터링합니다. 리소스 이름 패턴이 바뀐다면 `*_regex` 값을 함께 조정하세요.
- Notification Channel 리소스(이메일, Slack, PagerDuty 등)는 미리 생성해 `projects/<project>/notificationChannels/<id>` 형태로 전달해야 합니다.
