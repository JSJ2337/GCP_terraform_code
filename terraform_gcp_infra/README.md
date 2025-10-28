# GCP Terraform 인프라

Google Cloud Platform 인프라를 위한 프로덕션 레디 Terraform 모듈 및 구성.

## 개요

이 저장소는 GCP 및 Terraform 베스트 프랙티스를 따르는 재사용 가능한 Terraform 모듈과 환경별 구성을 포함합니다.

## 저장소 구조

```
terraform_gcp_infra/
├── modules/                    # 재사용 가능한 Terraform 모듈
│   ├── gcs-root/              # 다중 버킷 관리 래퍼
│   ├── gcs-bucket/            # 완전한 구성의 단일 GCS 버킷
│   ├── project-base/          # GCP 프로젝트 생성 및 기본 설정
│   ├── network-dedicated-vpc/ # 서브넷 및 방화벽이 있는 VPC 네트워킹
│   ├── iam/                   # IAM 역할 및 서비스 계정
│   ├── observability/         # 로깅 및 모니터링 설정
│   └── gce-vmset/             # Compute Engine VM 인스턴스
│
└── environments/              # 환경별 구성
    └── prod/
        └── proj-game-a/
            ├── 00-project/        # 프로젝트 설정
            ├── 10-network/        # 네트워크 구성
            ├── 15-storage/        # 스토리지 버킷
            ├── 20-security/       # 보안 및 IAM
            ├── 30-observability/  # 모니터링 및 로깅
            ├── 40-workloads/      # 컴퓨팅 워크로드
            └── locals.tf          # 공통 naming 및 labeling 규칙
```

## 주요 기능

### 모듈
- **모듈화 설계**: 작고 집중적이며 재사용 가능한 모듈
- **보안 우선**: Uniform bucket-level access, 공개 액세스 방지, Shielded VM
- **베스트 프랙티스**: Non-authoritative IAM 바인딩, 모듈 내 provider 블록 없음
- **포괄적**: 수명 주기 규칙, 버전 관리, 암호화, 모니터링

### 인프라 레이어
- **00-project**: GCP 프로젝트 생성, API 활성화, 예산 알림
- **10-network**: VPC, 서브넷, Cloud NAT, 방화벽 규칙
- **15-storage**: 에셋, 로그 및 백업용 GCS 버킷
- **20-security**: IAM 바인딩 및 서비스 계정
- **30-observability**: Cloud Logging 싱크 및 모니터링 대시보드
- **40-workloads**: Compute Engine 인스턴스

## 시작하기

### 사전 요구사항

```bash
# Terraform >= 1.6 설치
terraform version

# GCP 인증
gcloud auth application-default login

# 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID
```

### 초기 설정

1. **저장소 클론**
   ```bash
   git clone <repository-url>
   cd terraform_gcp_infra
   ```

2. **Terraform state용 GCS 버킷 생성**
   ```bash
   gsutil mb -p YOUR_PROJECT_ID -l US gs://gcp-tfstate-prod
   gsutil versioning set on gs://gcp-tfstate-prod
   ```

3. **변수 복사 및 구성**
   ```bash
   cd environments/prod/proj-game-a/00-project
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars 파일을 실제 값으로 수정
   ```

4. **백엔드 구성 업데이트**
   ```bash
   # backend.tf를 수정하여 state 버킷 지정
   vim backend.tf
   ```

### 배포 순서

인프라 레이어를 순서대로 배포:

```bash
# 1. 프로젝트 생성
cd environments/prod/proj-game-a/00-project
terraform init
terraform plan
terraform apply

# 2. 네트워크 생성
cd ../10-network
terraform init
terraform plan
terraform apply

# 3. 스토리지 생성
cd ../15-storage
terraform init
terraform plan
terraform apply

# 나머지 레이어도 동일하게 진행...
```

## 적용된 베스트 프랙티스

### 보안
- ✅ Uniform bucket-level access 기본 활성화
- ✅ 공개 액세스 방지 강제 적용
- ✅ Secure boot가 적용된 Shielded VM 인스턴스
- ✅ VPC 흐름 로그 활성화
- ✅ 충돌 방지를 위한 Non-authoritative IAM 바인딩
- ✅ CMEK 암호화 지원

### 운영
- ✅ 버전 관리가 적용된 GCS에서 State 관리
- ✅ 환경 및 레이어별 State 분리
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
- [gcs-root](modules/gcs-root/README.md) - 다중 버킷 관리
- [gcs-bucket](modules/gcs-bucket/README.md) - 단일 버킷 구성

## 일반적인 작업

### 새 버킷 추가

```hcl
# environments/prod/proj-game-a/15-storage/main.tf에서
# buckets map에 추가:
buckets = {
  # ... 기존 버킷들 ...

  new_bucket = {
    name          = "myorg-prod-game-a-new"
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
