# 첫 번째 프로젝트 배포

Bootstrap 설정이 완료되었다면 이제 실제 워크로드 프로젝트를 배포할 수 있습니다.

## 배포 순서 개요

```
00-project → 10-network → 20-storage → 30-security → 40-observability
                                   ↓
                            50-workloads → 60-database → 65-cache → 70-loadbalancer
```

> **순서가 중요합니다!** 각 레이어는 이전 레이어에 의존합니다.

## 옵션 1: 템플릿으로 시작 (권장)

### Step 1: 템플릿 복사

```bash
cd terraform_gcp_infra

# 새 환경 생성
cp -r proj-default-templet environments/LIVE/my-new-project
cd environments/LIVE/my-new-project
```

### Step 2: 공통 네이밍 설정

`common.naming.tfvars` 파일 수정:

```hcl
project_id     = "my-project-id"
project_name   = "my-new-project"
environment    = "prod"
organization   = "myorg"
region_primary = "asia-northeast3"
region_backup  = "asia-northeast1"
```

### Step 3: Terragrunt 설정 확인

`root.hcl` 파일 확인:

```hcl
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    project  = "jsj-system-mgmt"
    location = "asia"
    bucket   = "jsj-terraform-state-prod"
    prefix   = "my-new-project/${path_relative_to_include()}"
  }
}

inputs = {
  org_id          = ""  # 조직 ID (있는 경우)
  billing_account = "01076D-327AD5-FC8922"
  region_primary  = "asia-northeast3"
  region_backup   = "asia-northeast1"
}
```

## 레이어별 배포

### 1. 프로젝트 생성 (00-project)

```bash
cd 00-project

# 변수 파일 확인 (필요시 수정)
cat terraform.tfvars

# 배포
terragrunt init --non-interactive
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

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- VPC 네트워크
- 3개 서브넷 (DMZ, Private, DB)
- 방화벽 규칙
- Cloud NAT (DMZ only)
- Private Service Connect (DB용)

### 3. 스토리지 생성 (20-storage)

```bash
cd ../20-storage

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- GCS 버킷 (assets, logs, backups)
- Lifecycle 정책
- Versioning 설정

### 4. 보안 설정 (30-security)

```bash
cd ../30-security

# 서비스 계정 자동 생성 확인
cat terraform.tfvars
# auto_create_service_accounts = true

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- IAM 바인딩
- 서비스 계정 (web, app, db)

### 5. 모니터링 설정 (40-observability)

```bash
cd ../40-observability

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- Cloud Logging 싱크
- 모니터링 알림

### 6. 워크로드 배포 (50-workloads)

```bash
cd ../50-workloads

# VM 인스턴스 설정 확인
cat terraform.tfvars

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- VM 인스턴스 (역할별)
- 인스턴스 그룹
- Startup scripts

### 7. 데이터베이스 배포 (60-database)

```bash
cd ../60-database

# Private IP 설정 확인
cat terraform.tfvars
# private_ip_only = true

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- Cloud SQL MySQL
- Private IP 연결
- 백업 정책
- Read Replica (optional)

### 8. 캐시 배포 (65-cache)

```bash
cd ../65-cache

# Redis 설정 확인
cat terraform.tfvars

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스**:
- Memorystore Redis
- Standard HA 구성
- Private IP 연결

### 9. 로드밸런서 배포 (70-loadbalancers/\<서비스\>)

| 예시 경로 | 설명 |
|-----------|------|
| `70-loadbalancers/lobby` | 로비/인증 등 별도 롤의 LB 전용 |
| `70-loadbalancers/web`   | 웹 트래픽 전용 LB |

```bash
cd ../70-loadbalancers/lobby   # 또는 필요한 서비스 디렉터리

# LB 타입/이름 선택 (각 디렉터리의 terraform.tfvars에서 override 가능)
cat terraform.tfvars
# backend_service_name = "game-m-lobby-backend" 등

terragrunt init --non-interactive
terragrunt plan
terragrunt apply
```

**생성되는 리소스 (레이어별)**:
- HTTP(S)/Internal Load Balancer
- Health Check
- Backend Service (Terragrunt dependency를 통해 자동 연결)
- Forwarding Rule + Static IP (필요 시)

## 옵션 2: 일괄 배포 (스크립트)

```bash
cd environments/LIVE/my-new-project

# 전체 스택 Plan
terragrunt run --all plan

# 전체 스택 Apply
terragrunt run --all apply
```

## 배포 확인

### State 확인
```bash
# State 버킷 확인
gsutil ls gs://jsj-terraform-state-prod/my-new-project/

# 출력:
# gs://jsj-terraform-state-prod/my-new-project/00-project/
# gs://jsj-terraform-state-prod/my-new-project/10-network/
# ...
```

### 리소스 확인
```bash
# 프로젝트 확인
gcloud projects describe my-project-id

# 네트워크 확인
gcloud compute networks list --project=my-project-id

# VM 확인
gcloud compute instances list --project=my-project-id
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
