# 일반적인 오류 해결

Terraform/Terragrunt 사용 시 자주 발생하는 오류와 해결 방법입니다.

## State 관련 오류

### 1. "storage: bucket doesn't exist"

**증상**:

```text
Error: Failed to get existing workspaces: querying Cloud Storage failed:
storage: bucket doesn't exist
```

**원인**: Quota Project가 설정되지 않음

**해결**:

```bash
# Quota Project 설정
gcloud auth application-default set-quota-project jsj-system-mgmt

# 프로젝트 설정
gcloud config set project jsj-system-mgmt

# 재시도
terragrunt init -reconfigure
```

### 2. State Lock 걸림

**증상**:

```text
Error: Error acquiring the state lock
Lock Info:
  ID: 1761705035859250
  Path: gs://jsj-terraform-state-prod/...
```

**원인**: 이전 실행이 비정상 종료되어 Lock이 남아있음

**해결**:

```bash
# Lock 강제 해제 (Lock ID는 에러 메시지에서 확인)
terragrunt force-unlock 1761705035859250

# 또는 GCS에서 직접 삭제
gsutil rm gs://jsj-terraform-state-prod/path/to/default.tflock
```

### 3. "backend configuration changed"

**증상**:

```text
Error: Backend configuration changed
A change in the backend configuration has been detected
```

**해결**:

```bash
# Backend 재초기화
terragrunt init -reconfigure

# 또는 마이그레이션
terragrunt init -migrate-state
```

## 스크립트 관련 오류

### 4. gcp_project_guard.sh exit code 1

**증상**:

```text
🛡️  Ensuring GCP project prerequisites...
bash terraform_gcp_infra/scripts/gcp_project_guard.sh ensure 'terraform_gcp_infra/environments/LIVE/jsj-game-m'
[INFO] Project jsj-game-m already exists.
script returned exit code 1
```

**원인**:
- 스크립트가 `set -euo pipefail`로 실행되는데, early return 패턴 `|| return`이 exit code 1을 반환
- `FOLDER_ID`가 비어있거나 조건이 충족되지 않을 때 함수가 실패 상태로 반환

**해결**:

이 문제는 2025-11-17에 수정되었습니다. 최신 코드를 pull하세요:

```bash
git pull origin main
```

수정 내용:
- `ensure_project_parent()`: `return` → `return 0`
- `ensure_org_binding()`: `return` → `return 0`
- `ensure_billing_binding()`: `return` → `return 0`
- `ensure_project_binding()`: `return` → `return 0`
- `enable_apis()`: `return` → `return 0`

수동으로 수정하려면:

```bash
# 스크립트에서 모든 early return을 명시적으로 0 반환하도록 수정
sed -i 's/\] || return$/\] || return 0/g' terraform_gcp_infra/scripts/gcp_project_guard.sh
```

## 권한 관련 오류

### 5. "Permission denied"

**증상**:

```text
Error: googleapi: Error 403: Permission denied
The caller does not have permission
```

**원인**: Service Account 또는 User에게 필요한 권한이 없음

**해결**:

**방법 1**: ADC 재설정

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project jsj-system-mgmt
```

**방법 2**: Service Account 권한 확인

```bash
# SA 권한 확인
gcloud projects get-iam-policy jsj-game-k \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:jenkins-terraform-admin@*"

# 필요한 권한 부여
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud projects add-iam-policy-binding jsj-game-k \
    --member="${SA_MEMBER}" \
    --role="roles/editor"
```

### 6. Billing Account 권한 오류

**증상**:

```text
Error creating Budget: googleapi: Error 403
billingbudgets.googleapis.com API requires a quota project
```

**해결**:

**옵션 1**: Budget 비활성화 (권장)

```hcl
# terraform.tfvars
enable_budget = false
```

**옵션 2**: Billing User 권한 부여

```bash
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="${SA_MEMBER}" \
    --role="roles/billing.user"
```

## API 활성화 오류

### 7. "API not enabled"

**증상**:

```text
Error: Error creating Instance: googleapi: Error 403:
Compute Engine API has not been used in project xxx
```

**원인**: 필수 API가 활성화되지 않음

**해결**:

```bash
# 자주 필요한 API들
gcloud services enable \
    compute.googleapis.com \
    servicenetworking.googleapis.com \
    sqladmin.googleapis.com \
    redis.googleapis.com \
    cloudbilling.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project=jsj-game-k

# API 활성화 대기 (1-2분)
sleep 120

# 재시도
terragrunt apply
```

### 8. "Required plugins are not installed" - Provider Lock 파일

**증상**:

```text
Error: Required plugins are not installed

The installed provider plugins are not consistent with the packages
selected in the dependency lock file:
  - registry.terraform.io/hashicorp/google-beta: the cached package for
    registry.terraform.io/hashicorp/google-beta 7.11.0 (in .terraform/providers)
    does not match any of the checksums recorded in the dependency lock file
```

**원인**:
- `root.hcl`에서 모든 레이어에 google-beta provider를 generate
- 일부 레이어의 `.terraform.lock.hcl`에 google-beta checksum 누락
- 다른 플랫폼에서 lock 파일 생성 시 checksum 불일치

**해결**:

이 문제는 2025-11-17에 수정되었습니다. 최신 코드를 pull하세요:

```bash
git pull origin main
```

수동으로 수정하려면:

**옵션 1**: 정상 레이어에서 lock 파일 복사

```bash
# 00-project의 lock 파일을 다른 레이어에 복사
cd terraform_gcp_infra/environments/LIVE/jsj-game-m
cp 00-project/.terraform.lock.hcl 40-observability/.terraform.lock.hcl
cp 00-project/.terraform.lock.hcl 70-loadbalancers/web/.terraform.lock.hcl
```

**옵션 2**: terraform init -upgrade로 재생성

```bash
cd terraform_gcp_infra/environments/LIVE/jsj-game-m/40-observability
terraform init -upgrade
```

**옵션 3**: Jenkins 파이프라인 수정 (미래 예방)

Jenkinsfile의 init 단계에 `-upgrade` 추가:

```groovy
sh 'terraform init -upgrade -reconfigure'
```

### 9. "Service Networking API" 타이밍 이슈

**증상**:

```text
Error: Error creating private connection:
Service Networking API may not be enabled
```

**원인**: API 활성화 후 즉시 리소스 생성 시도

**해결**:

```bash
# 1. API 활성화
gcloud services enable servicenetworking.googleapis.com --project=jsj-game-k

# 2. 대기 (중요!)
sleep 120

# 3. 재시도
terragrunt apply
```

또는 `depends_on` 사용:

```hcl
resource "google_service_networking_connection" "private_vpc_connection" {
  depends_on = [google_project_service.servicenetworking]
  # ...
}
```

## 리소스 관련 오류

### 10. "resource not found"

**증상**:

```text
Error: Error reading Subnetwork: googleapi: Error 404:
The resource 'projects/xxx/regions/xxx/subnetworks/xxx' was not found
```

**원인**: 의존하는 리소스가 아직 생성되지 않음

**해결**:

```bash
# 1. 배포 순서 확인
cd ../10-network
terragrunt output -json

# 2. 의존 레이어가 완료되었는지 확인
terragrunt state list

# 3. 올바른 순서로 재배포
```

### 11. "already exists"

**증상**:

```text
Error: Error creating Network: googleapi: Error 409:
The resource 'projects/xxx/global/networks/xxx' already exists
```

**원인**: 리소스가 이미 존재하거나 State와 실제가 불일치

**해결**:

**옵션 1**: Import

```bash
# 기존 리소스를 State에 추가
terragrunt import google_compute_network.main \
    projects/jsj-game-k/global/networks/vpc-main
```

**옵션 2**: State 확인 및 동기화

```bash
# State 확인
terragrunt state list

# Refresh
terragrunt plan -refresh-only
terragrunt apply -refresh-only
```

## Terragrunt 관련 오류

### 12. "Unreadable module directory"

**증상**:

```text
Error: Unreadable module directory
Module directory .terragrunt-cache/... does not exist
```

**원인**: `terraform.source` 블록이 있어 복사 시도

**해결**:

```hcl
# terragrunt.hcl에서 제거
# terraform {
#   source = "."  # ← 이 블록 제거
# }
```

### 13. "Missing required GCS remote state configuration"

**증상**:

```text
Error: Missing required GCS remote state configuration
'project' and 'location' are required
```

**해결**:

```hcl
# root.hcl에 project와 location 추가
remote_state {
  backend = "gcs"
  config = {
    project  = "jsj-system-mgmt"  # 추가
    location = "asia"              # 추가
    bucket   = "jsj-terraform-state-prod"
    prefix   = "jsj-game-k/${path_relative_to_include()}"
  }
}
```

### 14. WSL "setsockopt: operation not permitted"

**증상**:

```text
Error: setsockopt: operation not permitted
```

**원인**: WSL1/일부 WSL2에서 Unix 소켓 제한

**해결**:

**옵션 1**: Linux VM/컨테이너 사용 (권장)

```bash
# Docker 컨테이너에서 실행
docker run -it --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    hashicorp/terraform:latest
```

**옵션 2**: WSL2 커널 업데이트

```bash
wsl --update
wsl --shutdown
```

## 네트워크 관련 오류

### 15. Private Service Connect 실패

**증상**:

```text
Error: Error creating service networking connection:
IP address range is already allocated
```

**원인**: IP 범위가 이미 할당됨

**해결**:

```bash
# 기존 연결 확인
gcloud services vpc-peerings list \
    --network=vpc-main \
    --project=jsj-game-k

# 연결 삭제 (조심!)
gcloud services vpc-peerings delete \
    --network=vpc-main \
    --service=servicenetworking.googleapis.com \
    --project=jsj-game-k
```

### 16. 방화벽 규칙 충돌

**증상**:

```text
Error: Error creating Firewall: googleapi: Error 409:
The resource 'projects/xxx/global/firewalls/xxx' already exists
```

**해결**:

```bash
# 기존 규칙 확인
gcloud compute firewall-rules list --project=jsj-game-k

# 수동으로 생성된 규칙 삭제
gcloud compute firewall-rules delete RULE_NAME --project=jsj-game-k

# 또는 Import
terragrunt import google_compute_firewall.rule_name \
    projects/jsj-game-k/global/firewalls/RULE_NAME
```

## Validation 오류

### 17. 변수 타입 불일치

**증상**:

```text
Error: Invalid value for input variable
The given value is not suitable for var.xxx
```

**해결**:

```hcl
# terraform.tfvars 확인
# 올바른 타입으로 수정

# 예시: 문자열이 아닌 숫자
machine_count = 3  # "3" 아님

# 예시: 리스트
allowed_ips = ["10.0.0.0/8", "192.168.0.0/16"]
```

## 디버깅 팁

### 상세 로그 활성화

```bash
# Terraform 로그
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Terragrunt 로그
export TERRAGRUNT_LOG_LEVEL=debug

# 실행
terragrunt plan

# 로그 비활성화
unset TF_LOG TF_LOG_PATH TERRAGRUNT_LOG_LEVEL
```

### State 검사

```bash
# State 백업
terragrunt state pull > state-backup.json

# State 분석
cat state-backup.json | jq '.resources[] | {type: .type, name: .name}'

# 특정 리소스 확인
terragrunt state show google_compute_network.main
```

### 캐시 정리

```bash
# Terragrunt 캐시
find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;

# Terraform 캐시
find . -type d -name ".terraform" -prune -exec rm -rf {} \;

# Lock 파일
find . -name ".terraform.lock.hcl" -delete
```

## Destroy 관련 오류

### 18. Terragrunt Dependency Outputs 에러 (Destroy 시)

**증상**:

```text
Run failed: 2 errors occurred:

* ./50-workloads/terragrunt.hcl is a dependency of ./70-loadbalancers/lobby/terragrunt.hcl
  but detected no outputs. Either the target module has not been applied yet,
  or the module has no outputs.
```

**원인**:
- Destroy 실행 순서상 50-workloads가 먼저 삭제됨
- 70-loadbalancers가 `dependency.workloads.outputs.instance_groups`를 읽으려고 시도
- 이미 삭제된 모듈의 outputs가 없어서 에러 발생

**해결** (2025-11-18 적용):

`get_terraform_command()` 함수로 조건부 처리:

```hcl
# 70-loadbalancers/lobby/terragrunt.hcl
dependency "workloads" {
  config_path = "../../50-workloads"

  mock_outputs = {
    instance_groups = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
}

locals {
  # destroy 명령어인지 확인
  is_destroy = get_terraform_command() == "destroy"
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  # destroy가 아닐 때만 auto_instance_groups 추가
  local.is_destroy ? {} : {
    auto_instance_groups = {
      for name, link in try(dependency.workloads.outputs.instance_groups, {}) :
      name => link
      if length(regexall("lobby", lower(name))) > 0
    }
  }
)
```

**효과**:
- Apply/Plan: 자동 instance_groups 매핑 (기능 유지)
- Destroy: dependency outputs를 읽지 않음 (에러 없음)

**참고**: `mock_outputs_merge_with_state`와 `mock_outputs_merge_strategy_with_state`는 작동하지 않음 (deprecated 또는 버그)

### 19. Service Networking Connection Destroy 실패

**증상**:

```text
Error: Unable to remove Service Networking Connection, err: Error waiting for Delete Service Networking Connection: Error code 9, message: Failed to delete connection; Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.
Help Token: REDACTED_HELP_TOKEN
```

**원인**:
- Terraform Provider Google 5.x의 알려진 버그
- Provider 4.x: `removePeering` 메서드 사용 (정상 작동)
- Provider 5.x: `deleteConnection` 메서드로 변경 (regression)
- CloudSQL/Redis가 이미 삭제되었어도 에러 발생

**해결** (2025-11-18 적용):

`deletion_policy = "ABANDON"` 추가:

```hcl
# modules/network-dedicated-vpc/main.tf
resource "google_service_networking_connection" "private_vpc_connection" {
  count   = var.enable_private_service_connection ? 1 : 0
  network = google_compute_network.vpc.self_link
  service = var.private_service_connection_service

  reserved_peering_ranges = local.private_service_connection_reserved_ranges

  # Terraform Provider Google 5.x 버그 우회
  deletion_policy = "ABANDON"

  depends_on = [google_compute_global_address.private_service_connect]
}
```

**ABANDON의 의미**:
- Destroy 시 GCP에서 실제로 삭제하지 않음
- Terraform state에서만 제거
- VPC 또는 프로젝트 삭제 시 자동으로 정리됨

**장점**:
- ✅ 슬립타임 불필요
- ✅ 항상 성공
- ✅ 완전 자동화 가능
- ✅ 안전 (VPC 삭제 시 함께 정리)

**기존 환경 처리**:

이미 생성된 Service Networking Connection이 있는 경우:

```bash
# 옵션 1: State에서 제거 (추천)
cd terraform_gcp_infra/environments/LIVE/jsj-game-m/10-network
terragrunt state rm module.network.google_service_networking_connection.private_vpc_connection[0]

# 옵션 2: 콘솔에서 수동 삭제
# GCP 콘솔 → VPC Network → VPC network peering → 삭제

# 다시 destroy
cd ..
terragrunt run-all destroy --terragrunt-non-interactive
```

**참고**:
- GitHub Issue #16275, #19908
- [Terraform Registry - google_service_networking_connection](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection)

### 20. Redis Cluster Deletion Protection

**증상**:

```text
Error: Error when reading or editing Cluster: googleapi: Error 400:
The cluster is deletion protected. Please disable deletion protection to delete the cluster.
```

**원인**: Redis Cluster의 `deletion_protection_enabled = true`

**해결**:

**방법 1**: Terraform 변수로 제어 (2025-11-18 적용)

```hcl
# terraform.tfvars
deletion_protection = false  # 개발/테스트 환경
```

**방법 2**: gcloud로 즉시 해제

```bash
# Cluster 확인
gcloud redis clusters list --region=asia-northeast3 --project=jsj-game-m

# Deletion protection 해제
gcloud redis clusters update CLUSTER_NAME \
  --region=asia-northeast3 \
  --no-deletion-protection \
  --project=jsj-game-m

# 확인
gcloud redis clusters describe CLUSTER_NAME \
  --region=asia-northeast3 \
  --project=jsj-game-m \
  --format="value(deletionProtectionEnabled)"
```

**모듈 업데이트** (이미 적용됨):

```hcl
# modules/memorystore-redis/variables.tf
variable "deletion_protection" {
  type        = bool
  description = "Deletion protection 활성화 여부 (true: 삭제 방지, false: 삭제 허용)"
  default     = true
}

# modules/memorystore-redis/main.tf
resource "google_redis_cluster" "enterprise" {
  deletion_protection_enabled = var.deletion_protection
  # ...
}
```

## Terragrunt 관련 오류

### "Unreadable module directory" (Source 경로 문제)

**증상**:

```text
Error: Unreadable module directory

Unable to evaluate directory symlink: lstat ../../../../../modules: no such
file or directory

The directory could not be read for module "naming" at main.tf:8.
```

**원인**:

Terragrunt의 `source` 메커니즘 제약:
1. `source`로 지정된 **단일 폴더만** `.terragrunt-cache`로 복사
2. 복사된 폴더 내부에서 상대 경로로 모듈 참조 시 경로 깨짐
3. 인접 폴더 (예: `modules/naming`, `modules/load-balancer`)는 복사되지 않음

**잘못된 패턴**:

```hcl
# terragrunt.hcl
terraform {
  source = "../_common"  # 또는 "../../../../../modules/some-module"
}

# _common/main.tf (source로 복사된 폴더)
module "naming" {
  source = "../../../../../modules/naming"  # ❌ .terragrunt-cache에서는 경로 없음
}
```

**해결 방법**:

**방법 1: In-place 실행 (권장)**

`source` 블록을 제거하고 현재 디렉토리에서 직접 실행:

```hcl
# terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# source 블록 없음 → in-place 실행

locals {
  # 설정...
}

inputs = merge(...)
```

이 방식은 10-network, 20-storage 등 대부분의 레이어에서 사용합니다.

**방법 2: 중복 코드 허용**

레이어 수가 적고 변경이 드문 경우, 중복을 허용:

```
70-loadbalancers/
├── lobby/
│   ├── main.tf         # 각 폴더에 파일 존재
│   ├── variables.tf
│   ├── outputs.tf
│   └── terragrunt.hcl  # source 없음
└── web/
    ├── main.tf         # lobby와 동일 (중복)
    ├── variables.tf
    ├── outputs.tf
    └── terragrunt.hcl  # source 없음
```

**방법 3: 정식 모듈화 (특별한 경우)**

모듈이 완전히 독립적이고 외부 모듈 참조가 없는 경우에만 사용:

```
modules/
└── my-module/
    ├── main.tf    # 외부 모듈 참조 없음
    ├── variables.tf
    └── outputs.tf

# terragrunt.hcl
terraform {
  source = "../../../../../modules/my-module"  # ✅ 단독으로 동작
}
```

**주의사항**:

- `//` 프리픽스는 **terragrunt.hcl 전용** (Terraform .tf 파일에서 사용 불가)
- 모듈 간 의존성이 있으면 공통화가 어려움
- 안정성 > 중복 제거 우선 고려

**관련 문서**:
- [작업 이력 (2025-11-18)](../changelog/work_history/2025-11-18.md) - 실제 문제 해결 과정
- [Terragrunt Source 문법](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#terraform)

---

## 긴급 복구

### State 복원

```bash
# Versioning된 State 리스트
gsutil ls -la gs://jsj-terraform-state-prod/jsj-game-k/00-project/

# 이전 버전 복원
STATE_OBJECT="gs://jsj-terraform-state-prod/jsj-game-k/00-project/default.tfstate#1234567890"
gsutil cp \
    "${STATE_OBJECT}" \
    gs://jsj-terraform-state-prod/jsj-game-k/00-project/default.tfstate
```

### Bootstrap State 복원

```bash
# 백업에서 복원
cd bootstrap
cp ~/backup/bootstrap-20250112.tfstate terraform.tfstate

# 또는 GCS에서
gsutil cp gs://jsj-terraform-state-prod/bootstrap/default.tfstate \
    terraform.tfstate
```

---

**다른 문제?**

- [State 문제](./state-issues.md)
- [네트워크 문제](./network-issues.md)
- [GitHub Issues](https://github.com/your-org/terraform-gcp-infra/issues)
