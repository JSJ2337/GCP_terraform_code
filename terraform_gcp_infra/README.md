# GCP Terraform 인프라

Google Cloud Platform 인프라를 위한 프로덕션 레디 Terraform 모듈 및 구성.

## 개요

이 저장소는 GCP 및 Terraform 베스트 프랙티스를 따르는 재사용 가능한 Terraform 모듈과 환경별 구성을 포함합니다.

## 저장소 구조

```
terraform_gcp_infra/
├── bootstrap/                  # ⭐ State 관리용 프로젝트 (최우선 배포)
│   ├── main.tf                # 관리용 프로젝트 및 State 버킷
│   ├── variables.tf           # 변수 정의
│   ├── terraform.tfvars       # 실제 설정 값
│   ├── outputs.tf             # 출력 값
│   └── README.md              # Bootstrap 가이드
│
├── modules/                    # 재사용 가능한 Terraform 모듈
│   ├── gcs-root/              # 다중 버킷 관리 래퍼
│   ├── gcs-bucket/            # 완전한 구성의 단일 GCS 버킷
│   ├── project-base/          # GCP 프로젝트 생성 및 기본 설정
│   ├── network-dedicated-vpc/ # 서브넷 및 방화벽이 있는 VPC 네트워킹
│   ├── iam/                   # IAM 역할 및 서비스 계정
│   ├── observability/         # 로깅 및 모니터링 설정
│   ├── gce-vmset/             # Compute Engine VM 인스턴스
│   ├── cloudsql-mysql/        # Cloud SQL MySQL 데이터베이스
│   └── load-balancer/         # HTTP(S) 및 Internal Load Balancer
│
└── environments/              # 환경별 구성
    └── prod/
        └── proj-default-templet/
            ├── 00-project/        # 프로젝트 설정
            ├── 10-network/        # 네트워크 구성
            ├── 20-storage/        # 스토리지 버킷
            ├── 30-security/       # 보안 및 IAM
            ├── 40-observability/  # 모니터링 및 로깅
            ├── 50-workloads/      # 컴퓨팅 워크로드
            ├── 60-database/       # Cloud SQL 데이터베이스
            ├── 70-loadbalancer/   # Load Balancer 설정
            └── locals.tf          # 공통 naming 및 labeling 규칙
```

## 주요 기능

### 모듈
- **모듈화 설계**: 작고 집중적이며 재사용 가능한 모듈
- **보안 우선**: Uniform bucket-level access, 공개 액세스 방지, Shielded VM
- **베스트 프랙티스**: Non-authoritative IAM 바인딩, 모듈 내 provider 블록 없음
- **포괄적**: 수명 주기 규칙, 버전 관리, 암호화, 모니터링

### 인프라 레이어
- **bootstrap**: 중앙 집중식 Terraform State 관리 프로젝트
- **00-project**: GCP 프로젝트 생성, API 활성화, 예산 알림
- **10-network**: VPC, 서브넷, Cloud NAT, 방화벽 규칙
- **20-storage**: 에셋, 로그 및 백업용 GCS 버킷
- **30-security**: IAM 바인딩 및 서비스 계정
- **40-observability**: Cloud Logging 싱크 및 모니터링 대시보드
- **50-workloads**: Compute Engine 인스턴스
- **60-database**: Cloud SQL MySQL 데이터베이스
- **70-loadbalancer**: HTTP(S) 및 Internal Load Balancer

### Locals를 통한 중앙 집중식 Naming
모든 프로젝트에는 **`locals.tf`** 파일이 포함되어 있으며, 모든 리소스 이름을 자동으로 생성합니다:

```hcl
# environments/prod/your-project/locals.tf
locals {
  project_name = "your-project"  # 이것만 변경하면
  organization = "your-org"

  # 모든 리소스 이름이 자동 생성됨
  vpc_name            = "${local.project_name}-${local.environment}-vpc"
  subnet_name_primary = "${local.project_name}-${local.environment}-subnet-${local.region_primary}"
  db_instance_name    = "${local.project_name}-${local.environment}-mysql"
  # ... 등등
}
```

**이점:**
- ✅ 새 프로젝트 생성 시 `locals.tf`만 수정
- ✅ 모든 리소스 이름이 일관된 패턴으로 자동 생성
- ✅ terraform.tfvars는 실제 설정값(CIDR, 포트 등)만 포함
- ✅ 버킷, 서비스 계정, Cloud SQL, Load Balancer 이름은 locals 기반 기본값을 자동 사용하므로 필요한 경우에만 override

## 시작하기

### 사전 요구사항

```bash
# Terraform >= 1.6 설치
terraform version

# GCP 인증
gcloud auth application-default login

# Billing Account ID 확인
gcloud billing accounts list
```

### 초기 설정

#### Step 1: Bootstrap 프로젝트 배포 (최우선!)

⚠️ **중요**: 다른 인프라를 배포하기 전에 반드시 Bootstrap 프로젝트를 먼저 배포해야 합니다.

```bash
# 1. 저장소 클론
git clone <repository-url>
cd terraform_gcp_infra

# 2. Bootstrap 디렉토리로 이동
cd bootstrap

# 3. terraform.tfvars 확인 및 수정 (필요시)
cat terraform.tfvars
# 프로젝트 ID, Billing Account 등 확인

# 4. Bootstrap 배포
terraform init
terraform plan
terraform apply

# 5. 출력 확인
terraform output
# → 버킷 이름: delabs-terraform-state-prod
# → 프로젝트 ID: delabs-system-mgmt

# 6. ⚠️ 로컬 state 파일 백업 (매우 중요!)
cp terraform.tfstate ~/backup/bootstrap-$(date +%Y%m%d).tfstate
```

**Bootstrap이 생성하는 것:**
- 관리용 GCP 프로젝트 (`delabs-system-mgmt`)
- 중앙 State 저장소 버킷 (`delabs-terraform-state-prod`)
- Versioning 및 Lifecycle 정책 자동 설정

#### Step 1.5: 인증 설정 (중요!)

Bootstrap 배포 후, 워크로드 프로젝트 배포 전에 인증을 설정해야 합니다:

```bash
# 중앙 State 버킷이 있는 프로젝트로 설정
gcloud config set project delabs-system-mgmt

# Application Default Credentials의 quota project 설정
gcloud auth application-default set-quota-project delabs-system-mgmt
```

⚠️ **이 단계를 생략하면 "storage: bucket doesn't exist" 오류가 발생합니다!**

#### Step 2: 워크로드 프로젝트 배포

Bootstrap 배포 후, 실제 워크로드 프로젝트를 배포합니다:

```bash
# 1. 환경 디렉토리로 이동
cd ../environments/prod/proj-default-templet/00-project

# 2. 변수 파일 준비
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
# 프로젝트 ID, 이름, Billing Account 등 설정

# 3. Backend는 이미 설정되어 있음
cat backend.tf
# bucket = "delabs-terraform-state-prod"
# prefix = "proj-default-templet/00-project"

# 4. 배포
terraform init  # 중앙 버킷에 연결
terraform plan
terraform apply
```

### 배포 순서

인프라 레이어를 **반드시 순서대로** 배포:

```bash
# 0. ⭐ Bootstrap (최우선 - 한 번만 실행)
cd bootstrap
terraform init && terraform apply
cd ..

# 1. 프로젝트 생성
cd environments/prod/proj-default-templet/00-project
terraform init
terraform plan
terraform apply

# 2. 네트워크 생성
cd ../10-network
terraform init
terraform plan
terraform apply

# 3. 스토리지 생성
cd ../20-storage
terraform init
terraform plan
terraform apply

# 4. 보안 및 IAM
cd ../30-security
terraform init
terraform plan
terraform apply

# 5. 모니터링 및 로깅
cd ../40-observability
terraform init
terraform plan
terraform apply

# 6. 워크로드 (VM 등)
cd ../50-workloads
terraform init
terraform plan
terraform apply

# 7. 데이터베이스
cd ../60-database
terraform init
terraform plan
terraform apply

# 8. 로드 밸런서
cd ../70-loadbalancer
terraform init
terraform plan
terraform apply
```

**배포 순서가 중요한 이유:**
- 각 레이어는 이전 레이어의 리소스에 의존
- State는 `delabs-terraform-state-prod` 버킷에 중앙 관리됨
- 각 레이어별로 독립적인 State 파일 유지

## 적용된 베스트 프랙티스

### State 관리 (⭐ 핵심)
- ✅ **중앙 집중식 State 관리**: 모든 프로젝트의 State를 단일 버킷에서 관리
- ✅ **Bootstrap 패턴**: 관리 인프라와 워크로드 인프라 분리
- ✅ **Versioning**: State 파일 버전 관리 (최근 10개 버전 보관)
- ✅ **Lifecycle 정책**: 30일 지난 State 버전 자동 정리
- ✅ **환경 및 레이어별 State 분리**: prefix를 통한 격리

### 보안
- ✅ Uniform bucket-level access 기본 활성화
- ✅ 공개 액세스 방지 강제 적용
- ✅ Secure boot가 적용된 Shielded VM 인스턴스
- ✅ VPC 흐름 로그 활성화
- ✅ 충돌 방지를 위한 Non-authoritative IAM 바인딩
- ✅ CMEK 암호화 지원
- ✅ Bootstrap 프로젝트 삭제 방지 (deletion_policy = PREVENT)

### 운영
- ✅ 프로젝트 삭제 시에도 State 보존
- ✅ 10개 이상 프로젝트 확장 가능한 구조
- ✅ 예산 알림 구성
- ✅ 포괄적인 로깅 및 모니터링
- ✅ locals를 통한 일관된 naming 규칙

### 코드 품질
- ✅ 모듈 내 provider 블록 없음
- ✅ optional 속성을 지원하는 Terraform >= 1.6
- ✅ 적용 가능한 곳에 입력 검증
- ✅ 모듈 조합을 위한 포괄적인 output
- ✅ 민감한 파일용 .gitignore

## 모듈 문서

각 모듈은 상세한 문서를 제공합니다:
- [Bootstrap](bootstrap/README.md) - State 관리용 프로젝트 (⭐ 필독)
- [gcs-root](modules/gcs-root/README.md) - 다중 버킷 관리
- [gcs-bucket](modules/gcs-bucket/README.md) - 단일 버킷 구성
- [project-base](modules/project-base/README.md) - GCP 프로젝트 생성
- [network-dedicated-vpc](modules/network-dedicated-vpc/README.md) - VPC 네트워킹
- [iam](modules/iam/README.md) - IAM 관리
- [observability](modules/observability/README.md) - 모니터링 및 로깅
- [gce-vmset](modules/gce-vmset/README.md) - VM 인스턴스
- [cloudsql-mysql](modules/cloudsql-mysql/README.md) - Cloud SQL MySQL 데이터베이스
- [load-balancer](modules/load-balancer/README.md) - HTTP(S) 및 Internal Load Balancer

## State 관리 아키텍처

### 구조

```
delabs-system-mgmt (관리용 프로젝트)
└── delabs-terraform-state-prod (GCS 버킷)
    ├── proj-default-templet/
    │   ├── 00-project/default.tfstate
    │   ├── 10-network/default.tfstate
    │   ├── 20-storage/default.tfstate
    │   ├── 60-database/default.tfstate
    │   ├── 70-loadbalancer/default.tfstate
    │   └── ...
    ├── proj-other-a/
    │   └── ...
    └── proj-other-b/
        └── ...
```

### 새 프로젝트 추가하기

**Step 1: 템플릿 복사**

```bash
# 템플릿 프로젝트 복사
cd environments/prod
cp -r proj-default-templet your-new-project
cd your-new-project
```

**Step 2: locals.tf 수정** (가장 중요!)

```hcl
# your-new-project/locals.tf
locals {
  project_name = "your-new-project"  # ← 이것만 변경!
  organization = "your-org"          # ← 조직명 변경
  environment  = "prod"

  # 나머지는 자동으로 계산됨
  # VPC 이름: your-new-project-prod-vpc
  # 서브넷: your-new-project-prod-subnet-us-central1
  # DB: your-new-project-prod-mysql
  # 등등...
}
```

**Step 3: backend.tf 업데이트** (모든 레이어)

```bash
# 모든 레이어의 backend.tf에서 prefix만 변경
for dir in */; do
  sed -i 's/proj-default-templet/your-new-project/g' "$dir/backend.tf"
done
```

**Step 4: terraform.tfvars 수정**

```bash
# 각 레이어의 terraform.tfvars에서 project_id만 변경
# 리소스 이름은 locals.tf에서 자동 생성되므로 수정 불필요!
```

**Step 5: 배포**

```bash
# 순서대로 배포
cd 00-project
terraform init && terraform apply
cd ../10-network
terraform init && terraform apply
# ... 계속
```

### Bootstrap State 백업 (중요!)

Bootstrap 프로젝트의 State는 로컬에 저장되므로 정기적으로 백업:

```bash
# 수동 백업
cd bootstrap
cp terraform.tfstate ~/backup/bootstrap-$(date +%Y%m%d).tfstate

# 또는 GCS에 업로드
gsutil cp terraform.tfstate gs://your-backup-bucket/bootstrap/

# 주기적 백업 (cron)
0 0 * * 0 cd /path/to/bootstrap && cp terraform.tfstate ~/backup/bootstrap-$(date +\%Y\%m\%d).tfstate
```

## 일반적인 작업

### 새 버킷 추가

```hcl
# environments/prod/proj-default-templet/20-storage/main.tf에서
# buckets map에 추가:
buckets = {
  # ... 기존 버킷들 ...

  new_bucket = {
    name          = "myorg-prod-default-templet-new"
    location      = "US-CENTRAL1"
    storage_class = "STANDARD"
  }
}
```

### IAM 바인딩 업데이트

```hcl
# IAM 바인딩은 non-authoritative 멤버 사용
iam_bindings = [
  {
    role = "roles/storage.objectViewer"
    members = [
      "user:admin@example.com",
      "serviceAccount:app@project.iam.gserviceaccount.com"
    ]
  }
]
```

### 수명 주기 규칙 구성

```hcl
lifecycle_rules = [
  {
    condition = {
      age = 90  # 일
    }
    action = {
      type = "Delete"
    }
  }
]
```

## 유지 관리

### 포맷팅
```bash
terraform fmt -recursive
```

### 검증
```bash
terraform validate
```

### 보안 스캔
```bash
# tfsec 설치
brew install tfsec

# 보안 문제 스캔
tfsec .
```

### 비용 추정
```bash
# infracost 설치
brew install infracost

# 비용 추정
infracost breakdown --path .
```

## 트러블슈팅

### 문제 1: "storage: bucket doesn't exist"

**증상:**
```
Error: Failed to get existing workspaces: querying Cloud Storage failed: storage: bucket doesn't exist
```

**해결:**
```bash
# 중앙 State 버킷이 있는 프로젝트로 변경
gcloud config set project delabs-system-mgmt
gcloud auth application-default set-quota-project delabs-system-mgmt

# terraform 재시도
terraform init -reconfigure
```

### 문제 2: State Lock 걸림

**증상:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: 1761705035859250
```

**해결:**
```bash
# Lock 강제 해제 (Lock ID는 에러 메시지에서 확인)
terraform force-unlock -force 1761705035859250
```

### 문제 3: Budget API 권한 오류

**증상:**
```
Error creating Budget: googleapi: Error 403
billingbudgets.googleapis.com API requires a quota project
```

**해결:**
이것은 알려진 문제이며, Budget 리소스만 영향을 받습니다 (다른 모든 리소스는 정상 생성됨).

**옵션 1:** terraform.tfvars에서 비활성화 (권장)
```hcl
enable_budget = false
```

**옵션 2:** GCP Console에서 수동 설정
- GCP Console → Billing → Budgets & alerts에서 예산 알림 생성

### 문제 4: 프로젝트 삭제 실패 (Lien)

**증상:**
```
Error: Cannot destroy project as deletion_policy is set to PREVENT
또는
Error: A lien to prevent deletion was placed on the project
```

**해결:**
```bash
# Lien 확인
gcloud alpha resource-manager liens list --project=PROJECT_ID

# Lien 삭제
gcloud alpha resource-manager liens delete LIEN_ID

# deletion_policy 변경 후 재시도
```

## 기여하기

1. 기존 모듈 구조 따르기
2. 새 모듈에 README.md 포함
3. terraform.tfvars.example 파일 추가
4. locals를 통한 일관된 naming 사용
5. 보안 기능 기본 활성화
6. `terraform validate` 및 `tfsec`로 테스트

## 지원

문제 또는 질문이 있는 경우:
1. 모듈 README 파일 확인
2. Terraform 및 GCP 문서 검토
3. 저장소에 이슈 등록

## 라이센스

[라이센스 정보]
