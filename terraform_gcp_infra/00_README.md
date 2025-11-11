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
│   ├── load-balancer/         # HTTP(S) 및 Internal Load Balancer
│   ├── memorystore-redis/     # Memorystore Redis 캐시
│   └── naming/                # 공통 네이밍/라벨 규칙 계산
│
├── proj-default-templet/       # 🎨 프로젝트 템플릿 (복사용)
│   ├── 00-project/            # 프로젝트 설정
│   ├── 10-network/            # 네트워크 구성
│   ├── 20-storage/            # 스토리지 버킷
│   ├── 30-security/           # 보안 및 IAM
│   ├── 40-observability/      # 모니터링 및 로깅
│   ├── 50-workloads/          # 컴퓨팅 워크로드
│   ├── 60-database/           # Cloud SQL 데이터베이스
│   ├── 65-cache/              # Memorystore Redis 캐시
│   ├── 70-loadbalancer/       # Load Balancer 설정
│   ├── common.naming.tfvars   # 공통 네이밍 변수
│   └── root.hcl               # Terragrunt 루트 설정
│
├── environments/               # 환경별 구성 (실제 배포 환경)
│   └── LIVE/
│       └── jsj-game-k/        # 현재 운영 대상 환경
│           ├── Jenkinsfile          # 🚀 jsj-game-k CI/CD Pipeline
│           ├── common.naming.tfvars # 프로젝트 메타데이터
│           └── 00-project/ ~ 70-loadbalancer/
│
├── .jenkins/                   # Jenkins 템플릿
│   ├── Jenkinsfile.template   # 재사용 가능한 Pipeline 템플릿
│   └── README.md              # 템플릿 사용 가이드
├── run_terragrunt_stack.sh    # Terragrunt 일괄 실행 스크립트
└── *.md                        # 프로젝트 문서
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
- **10-network**: VPC, 기본/DR 서브넷 + DMZ/Private/DB 전용 서브넷, DMZ 한정 Cloud NAT, Private Service Connect, 방화벽 규칙
- **20-storage**: 에셋, 로그 및 백업용 GCS 버킷
- **30-security**: IAM 바인딩 및 서비스 계정
- **40-observability**: Cloud Logging 싱크 및 모니터링 대시보드
- **50-workloads**: Compute Engine 인스턴스 (instances map 기반 역할별 구성, per-instance OS/서브넷/스크립트)
- **60-database**: Cloud SQL MySQL (Private IP, PSC 연동)
- **65-cache**: Memorystore Redis (Standard HA, Direct Peering)
- **70-loadbalancer**: HTTP(S) 및 Internal Load Balancer

### modules/naming을 통한 중앙 집중식 Naming
각 레이어는 `modules/naming` 모듈을 호출해 일관된 리소스 이름과 공통 라벨을 계산합니다. 입력 값은 각 환경의 `common.naming.tfvars` 한 곳에서 관리합니다 (예: `proj-default-templet/common.naming.tfvars`, `environments/LIVE/jsj-game-k/common.naming.tfvars`):

```hcl
# common.naming.tfvars
project_id     = "gcp-terraform-imsi"
project_name   = "default-templet"
environment    = "prod"
organization   = "myorg"
region_primary = "us-central1"
region_backup  = "us-east1"
```

`modules/naming`은 위 값을 이용해 `vpc_name`, `bucket_name_prefix`, `db_instance_name`, `sa_name_prefix`, `forwarding_rule_name` 등을 자동으로 만들어 주며, 공통 라벨(`common_labels`)과 태그(`common_tags`)도 함께 제공합니다. 리소스 이름을 변경하고 싶다면 `common.naming.tfvars`만 수정하면 모든 레이어가 동일하게 업데이트됩니다.

### Terragrunt 기반 실행
- 전체 레이어를 순서대로 실행하려면 `./run_terragrunt_stack.sh <plan|apply|destroy>` 스크립트를 사용하세요. Terragrunt 0.93 CLI의 `run --all`을 감싸며 추가 인자는 그대로 전달됩니다.
- 각 레이어에는 `terragrunt.hcl`이 존재하며, 공통 입력(`common.naming.tfvars`)과 레이어 전용 `terraform.tfvars`를 자동 병합합니다.
- 원격 상태(GCS)는 Terragrunt가 관리하며 루트 `root.hcl`이 각 레이어에 `backend.tf`를 자동 생성합니다. Terraform 코드에 별도의 backend 블록을 둘 필요가 없습니다.
- Terragrunt 0.93 CLI부터는 `terragrunt run --all <command>` 형태가 기본입니다. 특정 레이어만 플랜하고 싶다면 `terragrunt run --queue-include-dir '00-project' --all plan -- -out=tfplan-00-project`처럼 `run --queue-include-dir`를 사용하세요.
- Jenkins/CI 환경에서는 `TG_NON_INTERACTIVE=true`, `--working-dir <환경 루트>` 조합으로 비대화식 실행을 강제합니다.
- 루트(`environments/prod/proj-default-templet/root.hcl`)에서 원격 상태 버킷과 prefix를 정의하고, 각 레이어는 의존 관계(`dependencies` 블록)로 실행 순서를 보장합니다.
- `common.naming.tfvars`를 직접 `-var-file`로 넘길 필요가 없으며, Terragrunt가 자동으로 주입합니다.

### 레이어별 변수 예시 템플릿
- 모든 레이어에는 한글 주석이 포함된 `terraform.tfvars.example` 파일이 제공됩니다.
- 필요한 레이어 디렉터리에서 `cp terraform.tfvars.example terraform.tfvars`로 복사 후 값을 수정하세요.
- 주요 예시:
  - `00-project/terraform.tfvars.example`: 프로젝트/청구/예산 설정
  - `10-network/terraform.tfvars.example`: 서브넷 CIDR, 방화벽, Private Service Connect 예약
  - `30-security/terraform.tfvars.example`: IAM 바인딩, 서비스 계정 자동 생성 토글
  - `40-observability/terraform.tfvars.example`: 중앙 로그 싱크 및 대시보드 정의
  - `50-workloads/terraform.tfvars.example`: VM 수량, 역할별 instances map, startup_script_file, per-instance OS/서브넷
  - `60-database/terraform.tfvars.example`: Cloud SQL Private IP, 백업/로깅 세부 설정
  - `65-cache/terraform.tfvars.example`: Memorystore Redis 메모리 크기, 대체 존, 유지보수 창
  - `70-loadbalancer/terraform.tfvars.example`: LB 타입, CDN, IAP, 헬스 체크
- 템플릿에는 Private Service Connect, 라벨, 로그 정책 등 자주 묻는 항목에 대한 주석이 포함되어 있어 표준 구성을 빠르게 적용할 수 있습니다.

## 시작하기

### 사전 요구사항

```bash
# Terraform >= 1.6
terraform version

# Terragrunt >= 0.93
terragrunt --version  # alias 또는 절대 경로(`/mnt/d/jsj_wsl_data/terragrunt_linux_amd64`) 사용 가능

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
# → 버킷 이름: jsj-terraform-state-prod
# → 프로젝트 ID: jsj-system-mgmt

# 6. ⚠️ 로컬 state 파일 백업 (매우 중요!)
cp terraform.tfstate ~/backup/bootstrap-$(date +%Y%m%d).tfstate
```

**Bootstrap이 생성하는 것:**
- 관리용 GCP 프로젝트 (`jsj-system-mgmt`)
- 중앙 State 저장소 버킷 (`jsj-terraform-state-prod`)
- Versioning 및 Lifecycle 정책 자동 설정

#### Step 1.5: 인증 설정 (중요!)

Bootstrap 배포 후, 워크로드 프로젝트 배포 전에 인증을 설정해야 합니다:

```bash
# 중앙 State 버킷이 있는 프로젝트로 설정
gcloud config set project jsj-system-mgmt

# Application Default Credentials의 quota project 설정
gcloud auth application-default set-quota-project jsj-system-mgmt
```

⚠️ **이 단계를 생략하면 "storage: bucket doesn't exist" 오류가 발생합니다!**

#### Step 2: 워크로드 프로젝트 배포

Bootstrap 배포 후, 실제 워크로드 프로젝트를 배포합니다:

```bash
# 1. 환경 디렉토리로 이동
cd ../environments/LIVE/jsj-game-k/00-project  # 또는 proj-default-templet

# 2. 변수 파일 준비 (처음 한 번)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
# 프로젝트 ID, Billing Account, 라벨 등 설정
# 다른 레이어도 배포 전 동일한 방법으로
# terraform.tfvars.example → terraform.tfvars 로 복사 후 수정
# (예: 10-network는 `enable_private_service_connection`을 유지하면 Cloud SQL Private IP용
#     Service Networking(Private Service Connect) 연결이 자동 예약됩니다.)

# 3. Terragrunt 실행 (Terraform 명령과 동일하게 사용 가능)
terragrunt init   --non-interactive  # 원격 상태 및 provider 다운로드
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive  # 검토 후 --non-interactive 옵션 제거 가능

# 또는 에일리어스를 사용하지 않는 경우 (절대 경로)
/mnt/d/jsj_wsl_data/terragrunt_linux_amd64 plan
```

> Terragrunt가 `common.naming.tfvars`와 현재 레이어의 `terraform.tfvars`, 그리고 루트 `root.hcl`의 `inputs`를 자동으로 병합하므로 `-var-file` 옵션을 수동으로 전달할 필요가 없습니다. 환경 전체에 공통으로 적용할 값(예: `org_id`, `billing_account`)은 루트 `root.hcl`의 `inputs` 섹션에 정의하세요.
> ⚠️ WSL1/일부 WSL2 빌드에서는 Google Provider가 Unix 소켓 옵션을 설정하지 못해 `setsockopt: operation not permitted` 오류가 발생할 수 있습니다. 이 경우 Windows 터미널이 아닌 Linux VM/컨테이너에서 Terragrunt를 실행하거나, 최신 WSL2 커널로 업데이트하세요.

### 배포 순서

인프라 레이어를 **반드시 순서대로** 배포:

```bash
# 0. ⭐ Bootstrap (최우선 - 한 번만 실행)
cd bootstrap
terraform init && terraform apply
cd ..

# 1. 프로젝트 생성
cd environments/LIVE/jsj-game-k/00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 2. 네트워크 생성
cd ../10-network
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 3. 스토리지 생성
cd ../20-storage
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 4. 보안 및 IAM
cd ../30-security
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 5. 모니터링 및 로깅
cd ../40-observability
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 6. 워크로드 (VM 등)
cd ../50-workloads
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 7. 데이터베이스
cd ../60-database
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 8. 로드 밸런서
cd ../70-loadbalancer
terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**배포 순서가 중요한 이유:**
- 각 레이어는 이전 레이어의 리소스에 의존
- State는 `jsj-terraform-state-prod` 버킷에 중앙 관리됨
- 각 레이어별로 독립적인 State 파일 유지

## 적용된 베스트 프랙티스

### State 관리 (⭐ 핵심)
- ✅ **중앙 집중식 State 관리**: 모든 프로젝트의 State를 단일 버킷에서 관리
- ✅ **Bootstrap 패턴**: 관리 인프라와 워크로드 인프라 분리
- ✅ **Versioning**: State 파일 버전 관리 (최근 10개 버전 보관)
- ✅ **Lifecycle 정책**: 30일 지난 State 버전 자동 정리
- ✅ **환경 및 레이어별 State 분리**: prefix를 통한 격리
- ✅ **Terragrunt 자동화**: 각 레이어의 원격 상태 prefix와 공통 변수를 Terragrunt가 일관되게 관리
- ⚠️ **Bootstrap State는 로컬**: bootstrap은 의도적으로 local backend를 사용하므로 `terraform_gcp_infra/bootstrap/terraform.tfstate`를 백업하고, 파이프라인/다른 환경에서 참조할 수 있도록 GCS 복사본(예: `gs://jsj-terraform-state-prod/bootstrap/default.tfstate`)을 유지해야 합니다. Terraform 코드에서는 이 GCS 복사본을 `data "terraform_remote_state"`로 읽습니다.

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
- ✅ modules/naming을 통한 일관된 naming 규칙
- ✅ Terragrunt 도입 완료 (WSL에서 provider 소켓 제약이 있는 경우 Linux/컨테이너 환경에서 실행 권장)

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
jsj-system-mgmt (관리용 프로젝트)
└── jsj-terraform-state-prod (GCS 버킷)
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
# 템플릿을 LIVE 환경으로 복사
cp -r proj-default-templet environments/LIVE/your-new-project
cd environments/LIVE/your-new-project
```

**Step 2: 공통 네이밍 입력 수정**

`common.naming.tfvars` 파일에서 프로젝트/환경/조직 정보를 새 값으로 변경합니다.

```hcl
project_id     = "your-project-id"
project_name   = "your-new-project"
environment    = "prod"
organization   = "your-org"
region_primary = "us-central1"
region_backup  = "us-east1"
```

**Step 3: Terragrunt prefix 업데이트**
- `environments/LIVE/your-new-project/terragrunt.hcl`의 `project_state_prefix` 값을 새 프로젝트 이름으로 변경합니다.
- 각 레이어의 `terragrunt.hcl`은 상대 경로를 사용하므로 별도 수정이 필요 없습니다.

**Step 4: 레이어별 terraform.tfvars 세부 값만 조정**
- 네트워크 CIDR, 버킷 정책, VM 스펙 등 환경별 값만 필요에 따라 조정합니다.
- 이름과 라벨은 Step 2에서 입력한 값에 맞춰 `modules/naming`이 자동 생성합니다.

**Step 5: Jenkinsfile 복사 (CI/CD 사용 시)**

```bash
# Jenkinsfile 템플릿 복사
cp .jenkins/Jenkinsfile.template environments/LIVE/your-new-project/Jenkinsfile

# Jenkins Job 생성
# Script Path: environments/LIVE/your-new-project/Jenkinsfile
```

**Step 6: Terragrunt로 배포**

```bash
# 순서대로 배포
cd 00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

cd ../10-network
terragrunt init --non-interactive
terragrunt plan
terragrunt apply
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

## Jenkins CI/CD 통합

이 저장소는 Jenkins를 통한 자동화된 Terragrunt 배포를 지원합니다.

### Jenkins 설정

**Jenkins Docker 설정**: `../jenkins_docker/` 디렉터리 참조
- Jenkins LTS + Terraform 1.9.8 + Terragrunt 0.68.15 + Git 사전 설치
- GitHub Webhook 자동 빌드 지원
- ngrok을 통한 외부 접속 (선택)

**상세 가이드**:
- [Jenkins 초기 설정](../jenkins_docker/JENKINS_SETUP.md)
- [GitHub 연동](../jenkins_docker/GITHUB_INTEGRATION.md)
- [Terragrunt CI/CD Pipeline](../jenkins_docker/TERRAGRUNT_PIPELINE.md)

### Terragrunt CI/CD Pipeline

**Jenkinsfile 위치**: 각 환경 디렉터리 내 (예: `environments/LIVE/jsj-game-k/Jenkinsfile`, `environments/LIVE/proj-default-templet/Jenkinsfile`)

**템플릿**: `.jenkins/Jenkinsfile.template` (새 프로젝트 생성 시 복사)

**주요 기능**:
- ✅ Plan/Apply/Destroy 파라미터 선택
- ✅ 전체 스택 또는 개별 레이어 실행
- ✅ **수동 승인 단계** (Apply/Destroy 전 필수)
- ✅ 30분 승인 타임아웃
- ✅ Admin 사용자만 승인 가능

**Pipeline 단계**:
```
1. Checkout → 2. Environment Check → 3. Terragrunt Init
   ↓
4. Terragrunt Plan
   ↓
5. Review Plan (apply/destroy 시)
   ↓
6. 🛑 Manual Approval 🛑 (30분 타임아웃, admin 전용)
   ↓
7. Terragrunt Apply/Destroy
```

### GCP 인증 설정 (Jenkins용)

**중앙 관리 Service Account 방식** (권장):

#### 1. Bootstrap으로 Service Account 생성 (자동)

Bootstrap 배포 시 `jenkins-terraform-admin` Service Account가 자동으로 생성됩니다 (`bootstrap/main.tf` 참조).

```bash
cd bootstrap
terraform apply  # Service Account 자동 생성
```

**생성되는 리소스**:
- Service Account: `jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com`
- 조직 레벨 권한 (조직이 있는 경우):
  - `roles/resourcemanager.projectCreator` (프로젝트 생성)
  - `roles/billing.user` (청구 계정 연결)
  - `roles/editor` (리소스 관리)

#### 2. 프로젝트 생성 방식

**조직이 있는 경우**: Jenkins가 자동으로 프로젝트 생성 가능

**조직이 없는 경우**: 프로젝트를 수동으로 생성하고 권한 부여
```bash
# 1. 프로젝트 수동 생성
gcloud projects create YOUR-PROJECT-ID --name="Your Project Name"

# 2. Billing 계정 연결
gcloud beta billing projects link YOUR-PROJECT-ID \
    --billing-account=YOUR-BILLING-ACCOUNT-ID

# 3. Service Account에 프로젝트별 Editor 권한 부여
gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/editor"
```

#### 3. Key 파일 생성 및 Jenkins 등록

```bash
# 1. Key 다운로드 (bootstrap output 명령 사용)
cd bootstrap
terraform output jenkins_key_creation_command  # 명령어 확인 후 실행

# 또는 직접 실행:
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account=jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com \
    --project=jsj-system-mgmt

# 2. Jenkins에 Credential 등록
# Jenkins → Manage Jenkins → Credentials → Add Credentials
# - Kind: Secret file
# - File: jenkins-sa-key.json 업로드
# - ID: gcp-jenkins-service-account  ⚠️ 정확히 이 ID로 입력
# - Description: GCP Service Account for Jenkins Terraform
```

#### 4. Jenkinsfile 환경 변수 (이미 템플릿에 포함됨)

```groovy
environment {
    GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-jenkins-service-account')
    // ⚠️ workspace root 기준 절대 경로 사용
    TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/YOUR-PROJECT-NAME'
}
```

**⚠️ 중요**:
- Credential ID는 반드시 `gcp-jenkins-service-account`로 설정 (Jenkinsfile과 일치 필요)
- `TG_WORKING_DIR`은 workspace root 기준 절대 경로 사용 (`.` 사용 불가)
- 템플릿 복사 시 `YOUR-PROJECT-NAME`을 실제 프로젝트 이름으로 변경

**장점**:
- Infrastructure as Code로 Service Account 관리
- 하나의 SA로 모든 프로젝트 관리
- Key 교체 시 Jenkins에서 한 번만 변경
- 중앙 집중식 권한 관리 및 감사

**상세 내용**: `bootstrap/README.md` 및 [Terragrunt Pipeline 가이드](../jenkins_docker/TERRAGRUNT_PIPELINE.md) 참조

#### 5. Jenkins Service Account 권한 체크리스트
Jenkins가 Terragrunt를 통해 새 프로젝트를 만들고 청구 계정에 연결하려면 아래 권한이 모두 필요합니다.

- `jsj-system-mgmt` 프로젝트  
  - `roles/storage.admin` – State 버킷 읽기/쓰기  
  - (선택) `roles/editor` – Jenkins 자체 리소스 관리
- 조직 또는 폴더 (자동 프로젝트 생성 시)  
  - `roles/resourcemanager.projectCreator`  
  - `roles/editor`
- 청구 계정 `01076D-327AD5-FC8922`  
  - `roles/billing.user` – 새 프로젝트 청구 계정 연결을 위해 필수

권한 부여 예시:

```bash
# Billing Account 권한
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="serviceAccount:jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"

# State 버킷이 있는 관리 프로젝트
gcloud projects add-iam-policy-binding jsj-system-mgmt \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/storage.admin"
```

> ✅ `cloudbilling.googleapis.com`과 `serviceusage.googleapis.com`이 `jsj-system-mgmt` 프로젝트에서 활성화되어 있어야 합니다. bootstrap을 다시 적용하거나 아래 명령으로 확인하세요.
> ```bash
> gcloud services enable cloudbilling.googleapis.com serviceusage.googleapis.com --project=jsj-system-mgmt
> ```

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
gcloud config set project jsj-system-mgmt
gcloud auth application-default set-quota-project jsj-system-mgmt

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
4. modules/naming 기반 일관된 naming 사용
5. 보안 기능 기본 활성화
6. `terraform validate` 및 `tfsec`로 테스트

## 지원

문제 또는 질문이 있는 경우:
1. 모듈 README 파일 확인
2. Terraform 및 GCP 문서 검토
3. 저장소에 이슈 등록

## 라이센스

[라이센스 정보]
