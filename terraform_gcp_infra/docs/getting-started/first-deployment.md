# 첫 번째 프로젝트 배포

Bootstrap 설정이 완료되었다면 이제 실제 워크로드 프로젝트를 배포할 수 있습니다.

## 배포 순서 개요

Jenkins Phase 기반 배포 순서 (9 Phases):

```text
Phase 1: 00-project
    ↓
Phase 2: 10-network
    ↓
Phase 3: 12-dns
    ↓
Phase 4: 20-storage + 30-security (병렬 가능)
    ↓
Phase 5: 40-observability (Optional)
    ↓
Phase 6: 50-workloads
    ↓
Phase 7: 60-database + 65-cache (병렬 가능)
    ↓
Phase 8: 66-psc-endpoints
    ↓
Phase 9: 70-loadbalancers
```

> **순서가 중요합니다!** 각 레이어는 이전 레이어에 의존합니다.

## 옵션 1: 템플릿으로 시작 (권장)

### 1단계: 템플릿 복사

```bash
cd terraform_gcp_infra

# 새 환경 생성 (예: gcp-gcby 기반으로 gcp-newgame 생성)
cp -r proj-default-templet environments/LIVE/gcp-newgame
cd environments/LIVE/gcp-newgame
```

### 2단계: 공통 네이밍 설정

`common.naming.tfvars` 파일 수정:

```hcl
project_id     = "gcp-newgame"
project_name   = "newgame"
environment    = "live"
organization   = "delabs"
region_primary = "us-west1"
region_backup  = "us-west2"
```

### 3단계: Terragrunt 설정 확인

`root.hcl` 파일 확인:

```hcl
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    project  = "delabs-gcp-mgmt"
    location = "US"
    bucket   = "delabs-terraform-state-live"
    prefix   = "gcp-newgame/${path_relative_to_include()}"
  }
}

inputs = {
  org_id          = ""  # 조직 ID (있는 경우)
  billing_account = "XXXXXX-XXXXXX-XXXXXX"
  region_primary  = "us-west1"
  region_backup   = "us-west2"
}
```

## 레이어별 배포

### 1. 프로젝트 생성 (00-project)

```bash
cd 00-project

# 변수 파일 확인 (필요시 수정)
cat terraform.tfvars

# 배포
terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- GCP 프로젝트
- 필수 API 활성화
- 예산 알림 (optional)

### 2. 네트워크 생성 (10-network)

```bash
cd ../10-network

# Private Service Connect 확인 (DB용)
cat terraform.tfvars
# enable_private_service_connection = true

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- VPC 네트워크
- 3개 서브넷 (DMZ, Private, DB)
- 방화벽 규칙
- Cloud NAT (DMZ only)
- Private Service Connect (DB용)

### 3. DNS 생성 (12-dns)

```bash
cd ../12-dns

# DNS 설정 확인
cat terraform.tfvars

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- Cloud DNS Zone (Public/Private)
- DNS 레코드

### 4. 스토리지 생성 (20-storage)

```bash
cd ../20-storage

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- GCS 버킷 (assets, logs, backups)
- Lifecycle 정책
- Versioning 설정

### 5. 보안 설정 (30-security)

```bash
cd ../30-security

# 서비스 계정 자동 생성 확인
cat terraform.tfvars
# auto_create_service_accounts = true

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- IAM 바인딩
- 서비스 계정 (web, app, db)

### 6. 모니터링 설정 (40-observability)

```bash
cd ../40-observability

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- Cloud Logging 싱크
- 모니터링 알림

### 7. 워크로드 배포 (50-workloads)

```bash
cd ../50-workloads

# VM 인스턴스 설정 확인
cat terraform.tfvars

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- VM 인스턴스 (역할별)
- 인스턴스 그룹
- Startup scripts

### 8. 데이터베이스 배포 (60-database)

```bash
cd ../60-database

# Private IP 설정 확인
cat terraform.tfvars
# private_ip_only = true

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- Cloud SQL MySQL
- Private IP 연결
- 백업 정책
- Read Replica (optional)

### 9. 캐시 배포 (65-cache)

```bash
cd ../65-cache

# Redis 설정 확인
cat terraform.tfvars

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- Memorystore Redis
- Standard HA 구성
- Private IP 연결

### 10. PSC Endpoints 등록 (66-psc-endpoints)

```bash
cd ../66-psc-endpoints

# PSC 설정 확인
cat terraform.tfvars
# Cross-project PSC 등록 (mgmt VPC에서 접근용)

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- Cross-project PSC Endpoint 등록 (Cloud SQL, Redis)
- mgmt VPC에서 각 프로젝트 DB/Cache 접근 가능

> **참고**: Redis Cluster는 자체적으로 PSC를 자동 생성합니다 (`sca-auto-addr-*`). 66-psc-endpoints에서는 cross-project 등록만 수행합니다.

### 11. 로드밸런서 배포 (70-loadbalancers/\<서비스\>)

| 예시 경로 | 설명 |
|-----------|------|
| `70-loadbalancers/gs` | 게임 서버 LB (gcp-gcby) |
| `70-loadbalancers/www` | 웹 트래픽 전용 LB (gcp-web3) |
| `70-loadbalancers/mint` | Mint 서비스 LB (gcp-web3) |

```bash
cd ../70-loadbalancers/gs   # 또는 필요한 서비스 디렉터리

# LB 타입/이름 선택 (각 디렉터리의 terraform.tfvars에서 override 가능)
cat terraform.tfvars
# backend_service_name = "gcby-gs-backend" 등

terragrunt init
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:

- HTTP(S)/Internal Load Balancer
- Health Check
- Backend Service
- Forwarding Rule + Static IP (필요 시)

**자동 Instance Groups 매핑**:

70-loadbalancers는 `50-workloads`의 vm_details를 자동으로 읽어서 백엔드에 연결합니다.

```hcl
# 70-loadbalancers/gs/terragrunt.hcl
dependency "workloads" {
  config_path = "../../50-workloads"
  skip_outputs = get_env("SKIP_WORKLOADS_DEPENDENCY", "false") == "true"
}

inputs = {
  vm_details = try(dependency.workloads.outputs.vm_details, {})
}
```

**장점**: VM 추가/제거 시 Load Balancer 설정 자동 업데이트

> **주의**: `terraform.tfvars`에 `instance_groups = {}`를 정의하면 terragrunt inputs를 덮어씁니다. terragrunt에서 동적 주입하는 변수는 tfvars에서 정의하지 마세요.

## 옵션 2: 일괄 배포

```bash
cd environments/LIVE/gcp-newgame

# 전체 스택 Plan (Terragrunt 0.93+ 구문)
terragrunt run --all -- plan

# 전체 스택 Apply
terragrunt run --all -- apply

# 비대화식 실행 (CI/CD)
export TG_NON_INTERACTIVE=true
terragrunt run --all -- apply
```

## 배포 확인

### State 확인

```bash
# State 버킷 확인
gsutil ls gs://delabs-terraform-state-live/gcp-newgame/

# 출력:
# gs://delabs-terraform-state-live/gcp-newgame/00-project/
# gs://delabs-terraform-state-live/gcp-newgame/10-network/
# ...
```

### 리소스 확인

```bash
# 프로젝트 확인
gcloud projects describe gcp-newgame

# 네트워크 확인
gcloud compute networks list --project=gcp-newgame

# VM 확인
gcloud compute instances list --project=gcp-newgame
```

## 다음 단계

✅ 첫 배포가 완료되었다면:

- [Jenkins CI/CD 설정](../guides/jenkins-cicd.md)
- [새 프로젝트 추가하기](../guides/adding-new-project.md)
- [자주 쓰는 명령어](./quick-commands.md)

## 트러블슈팅

### "resource not found" 오류

- **원인**: 이전 레이어가 완료되지 않음
- **해결**: 순서대로 배포했는지 확인

### "API not enabled" 오류

- **원인**: 필수 API가 활성화되지 않음
- **해결**:

  ```bash
  gcloud services enable compute.googleapis.com \
      servicenetworking.googleapis.com \
      --project=my-project-id
  ```

### "dependency lock" 오류

- **원인**: .terraform.lock.hcl 파일 문제
- **해결**: `terragrunt init -reconfigure`

---

**관련 문서**:

- [Terragrunt 사용법](../guides/terragrunt-usage.md)
- [배포 순서 상세](../architecture/overview.md)
- [트러블슈팅](../troubleshooting/common-errors.md)
