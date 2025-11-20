# Bootstrap 설정

Bootstrap 프로젝트는 **중앙 집중식 Terraform State 관리**를 위한 핵심 인프라입니다.

> ⚠️ **중요**: 다른 모든 인프라를 배포하기 전에 반드시 Bootstrap을 먼저 배포해야 합니다.

## Bootstrap이 생성하는 리소스

```text
jsj-system-mgmt (관리용 프로젝트)
├── jsj-terraform-state-prod (GCS 버킷)
│   ├── Versioning 활성화
│   ├── Lifecycle 정책 (30일 후 삭제)
│   └── Uniform bucket-level access
├── jenkins-terraform-admin (Service Account)
└── 필수 API 활성화
```

## 1단계: 변수 파일 확인

```bash
cd bootstrap
cat terraform.tfvars
```

**주요 설정 항목**:

```hcl
# 관리용 프로젝트
management_project_id   = "jsj-system-mgmt"
management_project_name = "JSJ System Management"

# State 버킷
state_bucket_name = "jsj-terraform-state-prod"
state_bucket_location = "ASIA"

# Billing Account
billing_account = "01076D-327AD5-FC8922"

# 조직 설정 (있는 경우)
org_id = ""  # 조직 ID 또는 비워두기
```

## 2단계: Bootstrap 배포

```bash
cd bootstrap

# 1. 초기화
terraform init

# 2. 계획 확인
terraform plan

# 3. 적용
terraform apply
```

**예상 출력**:

```text
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

jenkins_service_account_email = "jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
management_project_id = "jsj-system-mgmt"
state_bucket_name = "jsj-terraform-state-prod"
```

## 3단계: Bootstrap State 백업 (중요!)

Bootstrap은 로컬 State를 사용하므로 **반드시 백업**해야 합니다.

```bash
# 로컬 백업
cp terraform.tfstate ~/backup/bootstrap-$(date +%Y%m%d).tfstate

# GCS 백업 (권장)
gsutil cp terraform.tfstate gs://jsj-terraform-state-prod/bootstrap/default.tfstate

# 정기 백업 (Cron) - 실제 crontab에는 한 줄로 입력
0 0 * * 0 cd /path/to/bootstrap && \
    cp terraform.tfstate \
    ~/backup/bootstrap-$(date +\%Y\%m\%d).tfstate
```

## 4단계: 인증 설정

Bootstrap 배포 후 **반드시** 다음을 실행하세요:

```bash
# 1. 프로젝트 설정
gcloud config set project jsj-system-mgmt

# 2. Quota Project 설정 (매우 중요!)
gcloud auth application-default set-quota-project jsj-system-mgmt
```

> ⚠️ 이 단계를 생략하면 "storage: bucket doesn't exist" 오류가 발생합니다!

## 5단계: Service Account 설정 (Jenkins용)

### 5-1. Key 파일 생성

```bash
# Bootstrap output에서 명령어 확인
cd bootstrap
terraform output jenkins_key_creation_command

# 또는 직접 실행
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account="${SA_EMAIL}" \
    --project=jsj-system-mgmt
```

### 5-2. 필수 권한 부여

**State 버킷 접근** (jsj-system-mgmt 프로젝트):

```bash
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud projects add-iam-policy-binding jsj-system-mgmt \
    --member="${SA_MEMBER}" \
    --role="roles/storage.admin"
```

**Billing Account 권한**:

```bash
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="${SA_MEMBER}" \
    --role="roles/billing.user"
```

**조직 레벨 권한** (조직이 있는 경우):

```bash
# 프로젝트 생성 권한
gcloud organizations add-iam-policy-binding YOUR_ORG_ID \
    --member="${SA_MEMBER}" \
    --role="roles/resourcemanager.projectCreator"

# 리소스 관리 권한
gcloud organizations add-iam-policy-binding YOUR_ORG_ID \
    --member="${SA_MEMBER}" \
    --role="roles/editor"
```

## 검증

### State 버킷 확인

```bash
gsutil ls -L gs://jsj-terraform-state-prod/

# Versioning: Enabled
# Location: ASIA
```

### Service Account 확인

```bash
gcloud iam service-accounts describe \
    jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com \
    --project=jsj-system-mgmt
```

## 다음 단계

✅ Bootstrap 설정이 완료되었다면:

- [첫 번째 프로젝트 배포하기](./first-deployment.md)

## 트러블슈팅

### "storage: bucket doesn't exist"

- **원인**: Quota Project가 설정되지 않음
- **해결**: `gcloud auth application-default set-quota-project jsj-system-mgmt`

### "billing account binding failed"

- **원인**: Billing User 권한 없음
- **해결**: Billing Account에 `roles/billing.user` 권한 부여

### "project already exists"

- **원인**: 프로젝트 ID 충돌
- **해결**: `terraform.tfvars`에서 다른 프로젝트 ID 사용

---

**관련 문서**:

- [사전 요구사항](./prerequisites.md)
- [첫 배포](./first-deployment.md)
- [State 관리](../architecture/state-management.md)
- [트러블슈팅](../troubleshooting/state-issues.md)
