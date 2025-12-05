# 모니터링 및 알림 설정 가이드

GCP Cloud Monitoring과 Slack을 연동하여 인프라 알림을 자동화하는 가이드입니다.

## 개요

이 프로젝트는 다음 리소스에 대한 자동 알림을 지원합니다:

- ✅ **GCE VM** - CPU 사용률 모니터링
- ✅ **Cloud SQL** - CPU 사용률 모니터링
- ✅ **Memorystore Redis** - 메모리 사용률 모니터링
- ✅ **Load Balancer** - 5xx 에러 모니터링

## 사전 준비사항

### 1. Slack Incoming Webhook 생성

1. Slack Workspace 설정 → **Apps**
2. **Incoming Webhooks** 검색 후 설치
3. **Add to Slack** 클릭
4. 알림을 받을 채널 선택 (예: `#game-alerts`)
5. **Webhook URL 복사** (다음 단계에서 사용)

   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
   ```

### 2. GCP 권한 확인

다음 권한이 필요합니다:

```bash
# Secret Manager 권한
roles/secretmanager.admin

# Monitoring 권한
roles/monitoring.admin
```

## 설정 단계

### 1단계: Slack Webhook URL을 Secret Manager에 저장

**⚠️ 중요**: Webhook URL은 절대 Git에 커밋하지 마세요!

헬퍼 스크립트를 사용하여 안전하게 저장:

```bash
cd terraform_gcp_infra

# Slack Webhook URL을 Secret Manager에 저장
./scripts/setup_slack_webhook.sh jsj-system-mgmt \
  "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**출력 예시**:

```
[INFO] Setting up Slack Webhook URL in Secret Manager...
[INFO] Project: jsj-system-mgmt
[INFO] Enabling Secret Manager API...
[INFO] Creating secret 'slack-webhook-url'...
[SUCCESS] Secret 'slack-webhook-url' created successfully.

Secret resource name:
  projects/jsj-system-mgmt/secrets/slack-webhook-url
```

### 2단계: terraform.tfvars 설정 확인

`environments/LIVE/jsj-game-m/40-observability/terraform.tfvars` 파일이 이미 설정되어 있습니다:

```hcl
# Slack Notifications
enable_slack_notifications    = true
slack_webhook_secret_name     = "slack-webhook-url"
slack_webhook_secret_project  = "jsj-system-mgmt"
slack_channel_name            = "#game-alerts"
slack_channel_display_name    = "Game-M Alerts"

# 알림 활성화
enable_vm_cpu_alert               = true
enable_cloudsql_cpu_alert         = true
enable_memorystore_memory_alert   = true
enable_lb_5xx_alert               = true
```

**커스터마이징**:

```hcl
# Slack 채널 변경
slack_channel_name = "#your-channel"

# 알림 임계값 조정
vm_cpu_threshold = 0.90  # 90%로 변경
lb_5xx_threshold = 20    # 분당 20개로 변경

# 특정 알림만 활성화
enable_vm_cpu_alert = true
enable_cloudsql_cpu_alert = false  # Cloud SQL 알림 비활성화
```

### 3단계: Terraform Apply

```bash
cd environments/LIVE/jsj-game-m

# 40-observability 레이어만 적용
cd 40-observability
terragrunt plan  # 변경사항 확인
terragrunt apply  # 적용
```

**예상 출력**:

```
Plan: 5 to add, 0 to change, 0 to destroy.

google_monitoring_notification_channel.slack[0]
google_monitoring_alert_policy.vm_cpu_high[0]
google_monitoring_alert_policy.cloudsql_cpu_high[0]
google_monitoring_alert_policy.memorystore_memory_high[0]
google_monitoring_alert_policy.lb_5xx_rate[0]
```

### 4단계: 테스트

알림이 정상적으로 작동하는지 확인:

1. **GCP Console 확인**:
   - **Monitoring** → **Alerting** → **Policies**
   - 생성된 Alert Policy 확인

2. **Slack 테스트 알림 발송**:

   ```bash
   # GCP Console에서 수동으로 테스트 알림 발송
   # Monitoring → Alerting → 특정 Policy → "Send Test Notification"
   ```

3. **실제 알림 확인**:
   - VM CPU를 의도적으로 높여서 알림 발생 확인
   - 또는 5분 대기 후 자동 모니터링 시작

## 알림 임계값 가이드

### VM CPU 알림

```hcl
vm_cpu_threshold = 0.85      # CPU 85% 사용 시 알림
vm_cpu_duration  = "300s"    # 5분 지속 시 트리거
```

**권장값**:
- **개발**: 0.90 (90%)
- **프로덕션**: 0.80 (80%)
- **크리티컬**: 0.70 (70%)

### Cloud SQL CPU 알림

```hcl
cloudsql_cpu_threshold = 0.75   # CPU 75% 사용 시 알림
cloudsql_cpu_duration  = "600s" # 10분 지속 시 트리거
```

**권장값**:
- **개발**: 0.85 (85%)
- **프로덕션**: 0.70 (70%)
- **크리티컬**: 0.60 (60%)

### Redis 메모리 알림

```hcl
memorystore_memory_threshold = 0.80  # 메모리 80% 사용 시 알림
memorystore_memory_duration  = "300s"
```

**권장값**:
- **개발**: 0.90 (90%)
- **프로덕션**: 0.80 (80%)
- **크리티컬**: 0.70 (70%) - eviction 위험

### Load Balancer 5xx 알림

```hcl
lb_5xx_threshold = 10      # 분당 10개 이상의 5xx 에러 시
lb_5xx_duration  = "300s"  # 5분 지속 시 트리거
```

**권장값**:
- **개발**: 50 (분당 50개)
- **프로덕션**: 10 (분당 10개)
- **크리티컬**: 5 (분당 5개)

## 리소스 필터 Regex 패턴

### VM 인스턴스

```hcl
# jsj-game-m으로 시작하는 모든 VM
vm_instance_filter_regex = "^jsj-game-m-.*"

# 특정 VM만 모니터링
vm_instance_filter_regex = "^jsj-game-m-(web|api|worker)-.*"

# 특정 VM 제외
vm_instance_filter_regex = "^jsj-game-m-(?!bastion).*"
```

### Cloud SQL

```hcl
# 형식: project:region:instance
cloudsql_instance_regex = "^jsj-game-m:asia-northeast3:jsj-game-m-mysql$"

# 모든 SQL 인스턴스
cloudsql_instance_regex = "^jsj-game-m:.*:.*$"
```

### Redis (Memorystore)

```hcl
# 형식: projects/{project}/locations/{region}/instances/{name}
memorystore_instance_regex = "^projects/jsj-game-m/locations/asia-northeast3/instances/jsj-game-m-redis$"

# 모든 Redis 인스턴스
memorystore_instance_regex = "^projects/jsj-game-m/locations/.*/instances/.*$"
```

### Load Balancer

```hcl
# HTTP/HTTPS proxy 모두
lb_target_proxy_regex = "^jsj-game-m-.*-(http|https)-proxy$"

# HTTP만
lb_target_proxy_regex = "^jsj-game-m-.*-http-proxy$"

# 특정 LB만
lb_target_proxy_regex = "^jsj-game-m-(web|api)-.*-proxy$"
```

## 트러블슈팅

### Secret Manager 접근 권한 오류

**증상**:

```
Error: Error retrieving available secret manager secret versions:
googleapi: Error 403: Permission 'secretmanager.versions.access' denied
```

**해결**:

```bash
# Terraform Service Account에 권한 부여
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"

gcloud secrets add-iam-policy-binding slack-webhook-url \
  --project=jsj-system-mgmt \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"
```

### Slack 알림이 오지 않음

**확인 사항**:

1. **Notification Channel 생성 확인**:

   ```bash
   gcloud alpha monitoring channels list --project=jsj-game-m
   ```

2. **Alert Policy 상태 확인**:

   ```bash
   gcloud alpha monitoring policies list --project=jsj-game-m
   ```

3. **Slack Webhook URL 검증**:

   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test from GCP Monitoring"}' \
     https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

4. **GCP Console에서 테스트**:
   - Monitoring → Alerting → Policy 선택 → "Send Test Notification"

### 알림이 너무 자주 옴

**조정**:

```hcl
# Duration 늘리기 (5분 → 10분)
vm_cpu_duration = "600s"

# 임계값 높이기 (80% → 90%)
vm_cpu_threshold = 0.90

# 특정 알림 비활성화
enable_vm_cpu_alert = false
```

### Regex 패턴이 매칭되지 않음

**디버깅**:

```bash
# 실제 리소스 이름 확인
gcloud compute instances list --project=jsj-game-m --format="table(name)"
gcloud sql instances list --project=jsj-game-m --format="value(connectionName)"
gcloud redis instances list --project=jsj-game-m --region=asia-northeast3
```

## 비용 최적화

### Monitoring 비용

- **무료 할당량**: 월 150MB까지 무료
- **초과 비용**: GB당 $0.2580 (2024년 기준)

### 비용 절감 팁

1. **Alert Policy 최소화**:

   ```hcl
   # 불필요한 알림 비활성화
   enable_lb_5xx_alert = false
   ```

2. **샘플링 간격 조정**:

   ```hcl
   # main.tf에서 alignment_period 늘리기
   alignment_period = "300s"  # 60s → 300s
   ```

3. **Regex 패턴 정확하게 지정**:

   ```hcl
   # 모든 VM 대신 특정 VM만
   vm_instance_filter_regex = "^jsj-game-m-web-.*"  # web 서버만
   ```

## 참고 자료

- [GCP Cloud Monitoring 문서](https://cloud.google.com/monitoring/docs)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Alert Policy 가격 책정](https://cloud.google.com/stackdriver/pricing)
- [Metric 필터 구문](https://cloud.google.com/monitoring/api/v3/filters)

---

**관련 문서**:

- [트러블슈팅 가이드](../troubleshooting/common-errors.md)
- [Jenkins CI/CD 가이드](../guides/jenkins-cicd.md)
