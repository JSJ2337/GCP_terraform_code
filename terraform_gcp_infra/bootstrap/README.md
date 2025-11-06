# 부트스트랩 - Terraform 상태 관리

이 디렉토리는 Terraform 상태를 저장하기 위한 관리용 프로젝트와 GCS 버킷을 생성합니다.

## 목적

- **관리용 GCP 프로젝트**: `delabs-system-mgmt`
- **상태 저장 버킷**: `delabs-terraform-state-prod`
- **Jenkins CI/CD용 Service Account**: `jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com`
- 모든 다른 프로젝트의 Terraform 상태를 여기에 중앙 관리
- Jenkins가 모든 프로젝트를 생성하고 관리할 수 있는 중앙 인증

## 중요 사항

⚠️ **이 프로젝트의 상태는 로컬에 저장됩니다**
- `terraform.tfstate` 파일이 로컬에 생성됨
- Git에 커밋하거나 안전한 곳에 백업 필요
- 이것은 부트스트랩 문제 해결을 위한 의도된 설계

## 사용 방법

### 1. terraform.tfvars 설정

**조직 ID 확인** (Service Account 권한 부여에 필요):
```bash
gcloud organizations list
```

**terraform.tfvars 수정**:
```hcl
organization_id = "123456789012"  # 위에서 확인한 조직 ID
```

### 2. 초기 배포

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

### 3. 배포 후 확인

```bash
# 프로젝트 확인
gcloud projects describe delabs-system-mgmt

# 버킷 확인
gsutil ls -L gs://delabs-terraform-state-prod

# Service Account 확인
gcloud iam service-accounts describe jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com \
    --project=delabs-system-mgmt
```

Cloud Billing API는 bootstrap이 자동으로 활성화합니다. 적용 직후 `gcloud services list --enabled --project delabs-system-mgmt | grep billing`으로 상태를 점검할 수 있습니다.

### 4. Jenkins용 Service Account Key 생성

**Key 파일 생성**:
```bash
# terraform output에서 명령어 확인
terraform output jenkins_key_creation_command

# 또는 직접 실행
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account=jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com \
    --project=delabs-system-mgmt
```

**Jenkins에 Credential 추가**:
1. Jenkins → Manage Jenkins → Credentials
2. (global) → Add Credentials
3. Kind: **Secret file** 선택
4. File: `jenkins-sa-key.json` 업로드
5. ID: `gcp-jenkins-service-account`
6. Save

**생성된 리소스 확인**:
```bash
# Service Account 이메일 확인
terraform output jenkins_service_account_email

# 권한 확인
gcloud organizations get-iam-policy YOUR_ORG_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com"
```

### 5. Service Account 추가 권한 설정

**State 버킷 접근 권한** (필수):
```bash
# delabs-system-mgmt 프로젝트에 Storage Admin 권한 부여
gcloud projects add-iam-policy-binding delabs-system-mgmt \
    --member="serviceAccount:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/storage.admin"
```

**Billing Account 연결 권한** (필수):
```bash
# 청구 계정에 billing.user 권한 부여
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="serviceAccount:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"
```

**워크로드 프로젝트 관리 권한** (프로젝트별로 부여):
```bash
# 각 워크로드 프로젝트에 Editor 권한 부여
gcloud projects add-iam-policy-binding <PROJECT_ID> \
    --member="serviceAccount:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/editor"
```

**권한 확인**:
```bash
# 특정 프로젝트의 Service Account 권한 확인
gcloud projects get-iam-policy delabs-system-mgmt \
    --flatten="bindings[].members" \
    --filter="bindings.members:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com"
```

### 6. 다른 프로젝트에서 사용

다른 프로젝트의 `terragrunt.hcl`:

```hcl
remote_state {
  backend = "gcs"
  config = {
    bucket   = "delabs-terraform-state-prod"
    prefix   = "proj-game-a/00-project"
    project  = "delabs-system-mgmt"  # 필수
    location = "US"                  # 필수
  }
}
```

또는 `backend.tf` (Terraform 직접 사용 시):

```hcl
terraform {
  backend "gcs" {
    bucket   = "delabs-terraform-state-prod"
    prefix   = "proj-game-a/00-project"
    project  = "delabs-system-mgmt"
    location = "US"
  }
}
```

## 생성되는 리소스

### 1. GCP 프로젝트
- **Project ID**: `delabs-system-mgmt`
- **Deletion Policy**: PREVENT (실수 삭제 방지)

### 2. GCS 버킷
- **Production**: `delabs-terraform-state-prod`
  - Versioning: 활성화 (최근 10개 버전 유지)
  - Lifecycle: 30일 지난 버전 자동 삭제
  - Force Destroy: false (삭제 보호)

### 3. Service Account
- **이름**: `jenkins-terraform-admin`
- **Email**: `jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com`
- **용도**: Jenkins CI/CD를 통한 Terraform/Terragrunt 자동화

### 4. IAM 권한 (조직/폴더 레벨)
- **Project Creator**: 새 GCP 프로젝트 생성 권한
- **Billing User**: 프로젝트에 청구 계정 연결 권한
- **Editor**: 생성된 프로젝트의 모든 리소스 관리 권한

---

## 상태 파일 백업

로컬 `terraform.tfstate` 파일 백업 방법:

### 옵션 1: Git에 암호화해서 저장
```bash
# git-crypt 또는 sops 사용
git-crypt init
git-crypt add-gpg-user <your-key>
```

### 옵션 2: 안전한 위치에 수동 백업
```bash
# 주기적으로 복사
cp terraform.tfstate ~/safe-backup/bootstrap-$(date +%Y%m%d).tfstate
```

### 옵션 3: 다른 GCS 버킷에 수동 업로드
```bash
gsutil cp terraform.tfstate gs://your-backup-bucket/bootstrap/
```

## 리소스 삭제 시 주의

⚠️ 이 프로젝트를 삭제하면 모든 프로젝트의 상태가 손실됩니다!

- `deletion_policy = "PREVENT"` 설정으로 실수 방지
- 버킷도 `force_destroy = false`로 보호

## 디렉토리 구조

```
bootstrap/
├── main.tf              # 프로젝트 및 버킷 정의
├── variables.tf         # 변수 정의
├── terraform.tfvars     # 실제 값
├── outputs.tf           # 출력값
├── terraform.tfstate    # ⚠️ 로컬 상태 (백업 필요!)
└── README.md            # 이 파일
```

## 버킷 설정

- **버전 관리**: 활성화 (최근 10개 버전 보관)
- **수명 주기**: 30일 지난 버전 자동 삭제
- **액세스**: 버킷 수준의 통합 액세스
- **위치**: US (다중 지역)
