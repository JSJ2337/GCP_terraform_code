# GCP Terraform Code

Google Cloud Platform 인프라를 위한 Terraform/Terragrunt 코드 저장소

## 개요

이 저장소는 GCP(Google Cloud Platform)에서 안전하고 확장 가능한 인프라를 구축하기 위한
Terraform 및 Terragrunt 코드를 포함합니다.

프로덕션급 인프라 구성을 위한 모듈화된 코드, 환경별 설정, CI/CD 파이프라인을 제공하며,
네트워크, 컴퓨팅, 데이터베이스, 보안, 모니터링 등 전체 인프라 스택을 코드로 관리합니다.

## 주요 특징

### 1. 완전 자동화된 인프라 관리

- **IaC (Infrastructure as Code)**: 모든 인프라를 코드로 정의
- **Terragrunt**: DRY 원칙 적용, 환경별 설정 관리
- **Jenkins 통합**: CI/CD 파이프라인 자동화
- **Phase 기반 배포**: 의존성 자동 해결

### 2. 모듈화된 구조

- 재사용 가능한 12개 이상의 Terraform 모듈
- 환경별 설정 분리 (Dev, Staging, Production)
- 프로젝트 템플릿 제공

### 3. 프로덕션 레디

- 고가용성 구성
- 보안 모범 사례 적용
- 모니터링 및 로깅 통합
- 재해 복구 지원

## 디렉토리 구조

```text
GCP_terraform_code/
├── terraform_gcp_infra/          # 메인 Terraform 코드
│   ├── bootstrap/                # 중앙 State 관리 (최우선 배포)
│   ├── modules/                  # 재사용 가능한 모듈
│   │   ├── compute/              # VM, GKE 등
│   │   ├── network/              # VPC, 서브넷, 방화벽
│   │   ├── database/             # Cloud SQL, Firestore
│   │   ├── storage/              # GCS, Persistent Disk
│   │   ├── security/             # IAM, Secret Manager
│   │   └── monitoring/           # Cloud Monitoring, Logging
│   ├── environments/             # 환경별 배포 설정
│   │   └── LIVE/
│   │       └── gcp-gcby/         # 프로덕션 환경
│   ├── proj-default-templet/     # 새 프로젝트 템플릿
│   ├── scripts/                  # 배포 스크립트
│   └── docs/                     # 문서화
├── jenkins_docker/               # Jenkins Docker 설정
└── ssh_vm_updated.sh             # VM SSH 접속 스크립트
```

## Phase 기반 배포 시스템

Jenkins CI/CD는 9개 Phase로 인프라를 순차 배포하여 의존성을 자동 해결합니다:

| Phase | 레이어 | 설명 |
|-------|--------|------|
| Phase 1 | `00-project` | GCP 프로젝트 생성 |
| Phase 2 | `10-network` | VPC 네트워킹 구성 |
| Phase 3 | `12-dns` | Cloud DNS (Public/Private) |
| Phase 4 | `20-storage`, `30-security` | 스토리지 및 IAM 보안 |
| Phase 5 | `40-observability` | Logging/Monitoring/Slack 알림 |
| Phase 6 | `50-workloads` | VM 인스턴스 배포 |
| Phase 7 | `60-database`, `65-cache` | Cloud SQL + Redis 캐시 |
| Phase 8 | `66-psc-endpoints` | Cross-project PSC 등록 |
| Phase 9 | `70-loadbalancers` | 로드밸런서 |

## 빠른 시작

### 사전 요구사항

- Terraform >= 1.0
- Terragrunt
- Google Cloud SDK (gcloud)
- GCP 프로젝트 및 권한
- Jenkins (선택사항)

### 1. Bootstrap 설정 (최초 1회)

```bash
cd terraform_gcp_infra/bootstrap
terraform init && terraform apply

# 인증 설정
gcloud auth application-default set-quota-project YOUR_MGMT_PROJECT
```

### 2. 환경 배포

**Jenkins 사용 (권장)**:

```text
TARGET_LAYER: all
ACTION: apply
ENABLE_OBSERVABILITY: true
```

**수동 배포**:

```bash
cd terraform_gcp_infra/environments/LIVE/gcp-gcby/00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

### 3. 결과 확인

```bash
terragrunt output -json | jq
```

## 주요 기능

### 네트워킹

- VPC 및 서브넷 자동 구성
- Cloud NAT 및 Cloud Router
- 방화벽 규칙 관리
- Private Service Connect (PSC)
- Cloud DNS (Public/Private)

### 컴퓨팅

- Compute Engine (VM) 자동 배포
- 인스턴스 템플릿 및 그룹
- 오토스케일링
- 멀티 존 고가용성

### 데이터베이스 및 캐시

- Cloud SQL (PostgreSQL, MySQL)
- Memorystore (Redis)
- 자동 백업 및 복제
- Private IP 연결

### 보안

- IAM 역할 및 정책
- Secret Manager 통합
- Service Account 관리
- VPC Service Controls

### 모니터링 및 로깅

- Cloud Monitoring 대시보드
- Cloud Logging
- Slack 알림 통합
- 커스텀 메트릭

## 스마트 자동화 기능

### 서브넷 자동 매핑

```hcl
# subnet_type만 지정하면 자동 매핑
subnet_type = "dmz"  # 10-network outputs에서 자동 매핑
```

### Zone 자동 변환

```hcl
# zone_suffix만 지정하면 region과 자동 결합
zone_suffix = "a"  # region_primary와 자동 결합 → us-west1-a
```

### 멀티 존 고가용성

```hcl
instances = {
  "web-01" = { zone_suffix = "a", subnet_type = "dmz" }
  "web-02" = { zone_suffix = "b", subnet_type = "dmz" }
  "web-03" = { zone_suffix = "c", subnet_type = "dmz" }
}
```

## Jenkins CI/CD 통합

### 주요 파이프라인

- **create-project**: 새 프로젝트 생성
- **deploy-infrastructure**: 인프라 배포
- **destroy-infrastructure**: 인프라 제거

### 파이프라인 파라미터

- `TARGET_LAYER`: all, network, compute, database 등
- `ACTION`: plan, apply, destroy
- `ENABLE_OBSERVABILITY`: true/false

## 모범 사례

### Terraform

- Remote State 사용 (GCS Backend)
- State 잠금 활성화
- 민감 정보는 Secret Manager 사용
- 모듈 버전 고정

### Terragrunt

- DRY 원칙 적용
- 환경별 변수 분리
- 의존성 명시적 정의

### 보안

- 최소 권한 원칙 적용
- Service Account 사용
- Private IP 우선 사용
- VPC Service Controls 활성화

### 비용 최적화

- 적절한 인스턴스 타입 선택
- 오토스케일링 활용
- 불필요한 리소스 정기 정리
- 예산 알림 설정

## VM SSH 접속

```bash
# 바스티온 호스트를 통한 SSH 접속
./ssh_vm_updated.sh
```

## 문서

상세한 문서는 `terraform_gcp_infra/docs/` 디렉토리를 참고하세요:

- Bootstrap 설정 가이드
- 첫 배포 가이드
- Jenkins CI/CD 가이드
- 모듈 사용법
- 트러블슈팅

## 트러블슈팅

### Terraform State 잠금 오류

```bash
# State 잠금 해제
terragrunt force-unlock LOCK_ID
```

### 권한 오류

```bash
# 현재 인증 정보 확인
gcloud auth list
gcloud config list project

# Application Default Credentials 재설정
gcloud auth application-default login
```

### 모듈 버전 충돌

```bash
# Terragrunt 캐시 정리
rm -rf .terragrunt-cache
terragrunt init --reconfigure
```

## 기여

내부 사용 목적의 Private 저장소입니다.

## 라이선스

Private Repository

## 참고 자료

- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [GCP Best Practices](https://cloud.google.com/architecture/framework)
