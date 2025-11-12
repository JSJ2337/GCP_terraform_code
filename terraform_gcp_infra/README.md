# GCP Terraform Infrastructure

Google Cloud Platform 인프라를 위한 프로덕션 레디 Terraform 모듈 및 환경 구성.

## 빠른 시작

### 1. 사전 요구사항
- Terraform >= 1.6 (권장: 1.10+)
- Terragrunt >= 0.93
- Google Cloud SDK
- [상세 가이드](./docs/getting-started/prerequisites.md)

### 2. Bootstrap 설정 (최우선!)
```bash
cd bootstrap
terraform init
terraform apply

# 인증 설정
gcloud auth application-default set-quota-project jsj-system-mgmt
```
[Bootstrap 상세 가이드](./docs/getting-started/bootstrap-setup.md)

### 3. 첫 프로젝트 배포
```bash
cd environments/LIVE/jsj-game-k/00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```
[첫 배포 가이드](./docs/getting-started/first-deployment.md)

## 프로젝트 구조

```
terraform_gcp_infra/
├── bootstrap/              # 중앙 State 관리 (최우선 배포)
├── modules/                # 재사용 가능한 모듈 (11개)
├── environments/           # 환경별 배포
│   └── LIVE/
│       ├── jsj-game-k/    # 프로덕션 환경
│       └── jsj-game-l/    # 추가 환경
└── proj-default-templet/   # 새 환경용 템플릿
```

### 인프라 레이어 (9단계)

| 레이어 | 목적 | 의존성 |
|--------|------|--------|
| `00-project` | GCP 프로젝트 생성 | Bootstrap |
| `10-network` | VPC, 서브넷, 방화벽 | 00-project |
| `20-storage` | GCS 버킷 | 10-network |
| `30-security` | IAM, Service Account | 10-network |
| `40-observability` | Logging, Monitoring | 10-network |
| `50-workloads` | VM 인스턴스 | 10-network, 30-security |
| `60-database` | Cloud SQL MySQL | 10-network |
| `65-cache` | Memorystore Redis | 10-network |
| `70-loadbalancer` | Load Balancer | 50-workloads |

## 문서

### 시작하기
- [사전 요구사항](./docs/getting-started/prerequisites.md)
- [Bootstrap 설정](./docs/getting-started/bootstrap-setup.md)
- [첫 배포](./docs/getting-started/first-deployment.md)
- [자주 쓰는 명령어](./docs/getting-started/quick-commands.md)

### 아키텍처
- [전체 구조](./docs/architecture/overview.md)
- [State 관리](./docs/architecture/state-management.md)
- [네트워크 설계](./docs/architecture/network-design.md)
- [다이어그램 모음](./docs/architecture/diagrams.md)

### 가이드
- [새 프로젝트 추가](./docs/guides/adding-new-project.md)
- [Jenkins CI/CD](./docs/guides/jenkins-cicd.md)
- [Terragrunt 사용법](./docs/guides/terragrunt-usage.md)
- [리소스 삭제 가이드](./docs/guides/destroy-guide.md)

### 트러블슈팅
- [일반적인 오류](./docs/troubleshooting/common-errors.md)
- [State 문제](./docs/troubleshooting/state-issues.md)
- [네트워크 문제](./docs/troubleshooting/network-issues.md)

### 변경 이력
- [CHANGELOG](./docs/changelog/CHANGELOG.md)
- [작업 이력](./docs/changelog/work_history/)

## 주요 기능

### 보안 우선
- DMZ/Private/DB 서브넷 분리
- Private IP only (DB, Redis)
- Shielded VM (Secure Boot)
- Non-authoritative IAM 바인딩

### 중앙 집중식 관리
- Bootstrap 기반 State 관리
- `modules/naming`으로 일관된 네이밍
- Terragrunt 자동화

### 프로덕션 레디
- 11개 재사용 모듈
- 환경별 독립 State
- Jenkins CI/CD 통합
- HA 구성 (Cloud SQL, Redis)

### 완전한 문서화
- 모든 모듈 README 포함
- 단계별 가이드
- 트러블슈팅 가이드
- Mermaid 다이어그램

## 네트워크 아키텍처

```
Internet → Load Balancer
              ↓
         DMZ Subnet (10.0.1.0/24)
         [Web VMs + Cloud NAT]
              ↓ (Internal Only)
         Private Subnet (10.0.2.0/24)
         [App VMs + Redis]
              ↓ (Private IP Only)
         DB Subnet (10.0.3.0/24)
         [Cloud SQL MySQL]
```

## 자주 쓰는 명령어

```bash
# 단일 레이어
cd environments/LIVE/jsj-game-k/00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 전체 스택
cd environments/LIVE/jsj-game-k
terragrunt run --all plan
terragrunt run --all apply

# State 확인
terragrunt state list
terragrunt output -json | jq

# 코드 포맷팅
terraform fmt -recursive
```

[전체 명령어 치트시트](./docs/getting-started/quick-commands.md)

## 재사용 가능한 모듈

| 모듈 | 기능 | 문서 |
|------|------|------|
| **naming** | 중앙 집중식 네이밍 | [README](./modules/naming/README.md) |
| **project-base** | GCP 프로젝트 생성 | [README](./modules/project-base/README.md) |
| **network-dedicated-vpc** | VPC 네트워킹 | [README](./modules/network-dedicated-vpc/README.md) |
| **gcs-root** | 다중 버킷 관리 | [README](./modules/gcs-root/README.md) |
| **gcs-bucket** | 단일 버킷 설정 | [README](./modules/gcs-bucket/README.md) |
| **iam** | IAM 관리 | [README](./modules/iam/README.md) |
| **observability** | Logging/Monitoring | [README](./modules/observability/README.md) |
| **gce-vmset** | VM 인스턴스 | [README](./modules/gce-vmset/README.md) |
| **cloudsql-mysql** | MySQL DB | [README](./modules/cloudsql-mysql/README.md) |
| **memorystore-redis** | Redis 캐시 | [README](./modules/memorystore-redis/README.md) |
| **load-balancer** | Load Balancer | [README](./modules/load-balancer/README.md) |

## 새 환경 추가

```bash
# 1. 템플릿 복사
cp -r proj-default-templet environments/LIVE/my-new-project

# 2. 네이밍 설정 수정
cd environments/LIVE/my-new-project
vim common.naming.tfvars

# 3. 순서대로 배포
cd 00-project && terragrunt apply
cd ../10-network && terragrunt apply
# ... 계속
```

[상세 가이드](./docs/guides/adding-new-project.md)

## 트러블슈팅

### "storage: bucket doesn't exist"
```bash
gcloud auth application-default set-quota-project jsj-system-mgmt
```

### State Lock 걸림
```bash
terragrunt force-unlock <LOCK_ID>
```

### API not enabled
```bash
gcloud services enable compute.googleapis.com \
    servicenetworking.googleapis.com \
    --project=<PROJECT_ID>
```

[전체 트러블슈팅 가이드](./docs/troubleshooting/common-errors.md)

## 기여하기

1. 모듈 구조 따르기
2. README.md 포함
3. `terraform.tfvars.example` 제공
4. `terraform fmt` 실행
5. `terraform validate` 통과

## 지원

- [GitHub Issues](https://github.com/your-org/terraform-gcp-infra/issues)
- [문서 포털](./docs/)

---

**Infrastructure Team**
