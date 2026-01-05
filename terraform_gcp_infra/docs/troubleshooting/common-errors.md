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
gcloud auth application-default set-quota-project delabs-gcp-mgmt

# 프로젝트 설정
gcloud config set project delabs-gcp-mgmt

# 재시도
terragrunt init -reconfigure
```

### 2. State Lock 걸림

**증상**:

```text
Error: Error acquiring the state lock
Lock Info:
  ID: 1761705035859250
  Path: gs://delabs-terraform-state-live/...
```

**원인**: 이전 실행이 비정상 종료되어 Lock이 남아있음

**해결**:

```bash
# Lock 강제 해제 (Lock ID는 에러 메시지에서 확인)
terragrunt force-unlock 1761705035859250

# 또는 GCS에서 직접 삭제
gsutil rm gs://delabs-terraform-state-live/path/to/default.tflock
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
bash terraform_gcp_infra/scripts/gcp_project_guard.sh ensure 'terraform_gcp_infra/environments/LIVE/gcp-gcby'
[INFO] Project gcp-gcby already exists.
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
gcloud auth application-default set-quota-project delabs-gcp-mgmt
```

**방법 2**: Service Account 권한 확인

```bash
# SA 권한 확인
gcloud projects get-iam-policy gcp-gcby \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:jenkins-terraform-admin@*"

# 필요한 권한 부여
SA_EMAIL="jenkins-terraform-admin@delabs-gcp-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud projects add-iam-policy-binding gcp-gcby \
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
SA_EMAIL="jenkins-terraform-admin@delabs-gcp-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud beta billing accounts add-iam-policy-binding XXXXXX-XXXXXX-XXXXXX \
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
    --project=gcp-gcby

# API 활성화 대기 (1-2분)
sleep 120

# 재시도
terragrunt apply
```

### 8. "Required plugins are not installed" - Provider Checksum 불일치

**증상**:

```text
Error: Required plugins are not installed

The installed provider plugins are not consistent with the packages
selected in the dependency lock file:
  - registry.terraform.io/hashicorp/null: the cached package for
    registry.terraform.io/hashicorp/null 3.2.4 (in .terraform/providers)
    does not match any of the checksums recorded in the dependency lock file
```

**원인**:
- Jenkins의 `TF_PLUGIN_CACHE_DIR`에 캐시된 provider와 `.terraform.lock.hcl`의 checksum 불일치
- 다른 플랫폼에서 lock 파일 생성 시 checksum 불일치
- Provider 버전 업데이트 후 캐시 불일치

**해결**:

이 문제는 2025-11-25에 Jenkinsfile에서 자동 처리되도록 수정되었습니다:

```bash
git pull origin main
```

**Jenkinsfile 변경 내용**:
- `.terraform.lock.hcl` 파일 삭제 추가
- `init` → `init -upgrade`로 변경

수동으로 수정하려면:

**옵션 1**: lock 파일 삭제 후 재생성

```bash
cd terraform_gcp_infra/environments/LIVE/gcp-gcby/70-loadbalancers/gs
rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
```

**옵션 2**: 전체 레이어 lock 파일 정리

```bash
cd terraform_gcp_infra/environments/LIVE/gcp-gcby
find . -name ".terraform.lock.hcl" -delete
find . -type d -name ".terraform" -prune -exec rm -rf {} +
terragrunt run --all -- init -upgrade
```

**옵션 3**: Jenkins 파이프라인 수정 (2025-11-25 적용됨)

```groovy
// init 전에 lock 파일 삭제
sh """
    find '${env.WORKSPACE}/${TG_WORKING_DIR}' -name ".terraform.lock.hcl" -type f -delete || true
"""
// -upgrade 옵션으로 provider 재다운로드
sh "terragrunt run --all --working-dir '${env.WORKSPACE}/${TG_WORKING_DIR}' -- init -upgrade"
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
gcloud services enable servicenetworking.googleapis.com --project=gcp-gcby

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
    projects/gcp-gcby/global/networks/gcby-live-vpc
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
    project  = "delabs-gcp-mgmt"  # 추가
    location = "US"                # 추가
    bucket   = "delabs-terraform-state-live"
    prefix   = "gcp-gcby/${path_relative_to_include()}"
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
    --network=gcby-live-vpc \
    --project=gcp-gcby

# 연결 삭제 (조심!)
gcloud services vpc-peerings delete \
    --network=gcby-live-vpc \
    --service=servicenetworking.googleapis.com \
    --project=gcp-gcby
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
gcloud compute firewall-rules list --project=gcp-gcby

# 수동으로 생성된 규칙 삭제
gcloud compute firewall-rules delete RULE_NAME --project=gcp-gcby

# 또는 Import
terragrunt import google_compute_firewall.rule_name \
    projects/gcp-gcby/global/firewalls/RULE_NAME
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

**해결** (2025-11-18 최종):

환경변수 기반 `skip_outputs` 제어:

```hcl
# 70-loadbalancers/lobby/terragrunt.hcl
dependency "workloads" {
  config_path = "../../50-workloads"

  # SKIP_WORKLOADS_DEPENDENCY=true 환경변수 설정 시 outputs 건너뛰기
  skip_outputs = get_env("SKIP_WORKLOADS_DEPENDENCY", "false") == "true"

  mock_outputs = {
    instance_groups = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    auto_instance_groups = {
      for name, link in try(dependency.workloads.outputs.instance_groups, {}) :
      name => link
      if length(regexall("lobby", lower(name))) > 0
    }
  }
)
```

**사용법**:

```bash
# 일반 사용 (자동 매핑 ✅)
cd 70-loadbalancers/lobby
terragrunt apply

# run-all destroy (환경변수 설정, Terragrunt 0.93+)
cd environments/LIVE/gcp-gcby
export TG_NON_INTERACTIVE=true
SKIP_WORKLOADS_DEPENDENCY=true terragrunt run --all -- destroy
```

**효과**:
- 일반 apply/plan: 자동 instance_groups 매핑 유지
- run-all destroy: 환경변수 설정으로 dependency 건너뛰기
- 유연한 제어: 필요할 때만 환경변수 사용

**작동하지 않는 방법들**:
- `mock_outputs_merge_with_state = true` - deprecated
- `mock_outputs_merge_strategy_with_state = "shallow"` - 작동 안 함
- `get_terraform_command()` 조건 분기 - dependency 평가 시점에 이미 에러

### 19. Service Networking Connection Destroy 실패

**증상**:

```text
Error: Unable to remove Service Networking Connection, err: Error waiting for Delete Service Networking Connection: Error code 9, message: Failed to delete connection; Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.
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
cd terraform_gcp_infra/environments/LIVE/gcp-gcby/10-network
terragrunt state rm module.network.google_service_networking_connection.private_vpc_connection[0]

# 옵션 2: 콘솔에서 수동 삭제
# GCP 콘솔 → VPC Network → VPC network peering → 삭제

# 다시 destroy (Terragrunt 0.93+)
cd ..
export TG_NON_INTERACTIVE=true
terragrunt run --all -- destroy
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
gcloud redis clusters list --region=us-west1 --project=gcp-gcby

# Deletion protection 해제
gcloud redis clusters update CLUSTER_NAME \
  --region=us-west1 \
  --no-deletion-protection \
  --project=gcp-gcby

# 확인
gcloud redis clusters describe CLUSTER_NAME \
  --region=us-west1 \
  --project=gcp-gcby \
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

## Load Balancer 관련 오류

### Invalid index (vm_details 참조 오류)

**증상**:

```text
Error: Invalid index
on main.tf line 39, in locals:
  39:           self_link = var.vm_details[inst_name].self_link
│ var.vm_details is map of object with 2 elements
The given key does not identify an element in this collection value.
```

**원인**:
- terraform.tfvars에 instance_groups 정의는 있지만
- 해당 VM이 아직 50-workloads에서 생성되지 않음
- vm_details에 존재하지 않는 키를 참조하려고 함

**해결**:

```hcl
# main.tf에서 안전한 필터링 추가
resolved_instances = [
  for inst_name in cfg.instances : {
    name      = inst_name
    self_link = var.vm_details[inst_name].self_link
    zone      = var.vm_details[inst_name].zone
  }
  if contains(keys(var.vm_details), inst_name)  # ← 추가
]
```

**관련 문서**: [작업 이력 (2025-11-28)](../changelog/work_history/2025-11-28.md#1-jenkins-plan-stage-에러-수정-invalid-index)

---

### Resource precondition failed (빈 Instance Group)

**증상**:

```text
Error: Resource precondition failed
on main.tf line 191:
  condition = length(distinct([for inst in each.value.resolved_instances : inst.zone])) == 1
│ each.value.resolved_instances is empty tuple
instance group에는 동일한 존의 VM만 포함해야 합니다.
```

**원인**:
- VM 필터링 후 resolved_instances가 빈 배열이 됨
- Precondition이 빈 배열을 처리하지 못함

**해결**:

두 가지 접근:

1. **2단계 필터링 추가**:
```hcl
# 1단계: 모든 Instance Group 처리
_all_instance_groups = { ... }

# 2단계: 빈 Instance Group 제거
processed_instance_groups = {
  for name, ig in local._all_instance_groups :
  name => ig
  if length(ig.resolved_instances) > 0
}

# 리소스에서 processed_instance_groups 사용
resource "google_compute_instance_group" "lb_instance_group" {
  for_each = local.processed_instance_groups
  # ...
}
```

2. **Precondition 개선**:
```hcl
lifecycle {
  precondition {
    # 빈 배열 허용 추가
    condition = length(each.value.resolved_instances) == 0 ||
                length(distinct([for inst in each.value.resolved_instances : inst.zone])) == 1
    error_message = "..."
  }
}
```

**관련 문서**: [작업 이력 (2025-11-28)](../changelog/work_history/2025-11-28.md#2-precondition-에러-수정)

---

### ❌ vm_details.auto.tfvars 파일 생성 금지

**증상**:
- Instance Group이 계획대로 생성/삭제되지 않음
- VM 추가/삭제 시 수동 업데이트 필요

**원인**:
- vm_details.auto.tfvars 파일을 수동으로 생성함
- Terragrunt dependency의 자동 주입을 수동 파일이 덮어씀

**올바른 방법**:

```hcl
# terragrunt.hcl에서 자동 주입 (파일 생성 불필요)
dependency "workloads" {
  config_path = "../../50-workloads"
}

inputs = merge(
  ...
  {
    # 자동으로 가져옴 - 파일 만들지 마세요!
    vm_details = try(dependency.workloads.outputs.vm_details, {})
  }
)
```

**절대 금지**:
```bash
# ❌ 이런 파일 만들지 마세요!
echo 'vm_details = { ... }' > vm_details.auto.tfvars
```

**해결**:
```bash
# 잘못 만든 파일 삭제
git rm vm_details.auto.tfvars
git commit -m "Remove manual vm_details file"
```

**관련 문서**: [작업 이력 (2025-11-28)](../changelog/work_history/2025-11-28.md#4-vm_detailsautotfvars-삭제-중요)

---

## 긴급 복구

### State 복원

```bash
# Versioning된 State 리스트
gsutil ls -la gs://delabs-terraform-state-live/gcp-gcby/00-project/

# 이전 버전 복원
STATE_OBJECT="gs://delabs-terraform-state-live/gcp-gcby/00-project/default.tfstate#1234567890"
gsutil cp \
    "${STATE_OBJECT}" \
    gs://delabs-terraform-state-live/gcp-gcby/00-project/default.tfstate
```

### Bootstrap State 복원

Bootstrap도 GCS backend를 사용합니다 (레이어 구조: `bootstrap/00-foundation`, `bootstrap/10-network` 등):

```bash
# 1. 버전 리스트 확인 (00-foundation 레이어 예시)
gsutil ls -la gs://delabs-terraform-state-live/bootstrap/00-foundation/

# 2. 특정 버전 복원
STATE_OBJECT="gs://delabs-terraform-state-live/bootstrap/00-foundation/default.tfstate#1234567890"
gsutil cp "${STATE_OBJECT}" gs://delabs-terraform-state-live/bootstrap/00-foundation/default.tfstate
```

---

## DNS Zone 관련 오류

### dnsNameInUse 에러 (DNS Zone 충돌)

**증상:**

```text
Error: Error updating ManagedZone "projects/delabs-gcp-mgmt/managedZones/delabsgames-internal":
googleapi: Error 400: The DNS name 'delabsgames.internal.' is already being used on network 'gcby-live-vpc'., dnsNameInUse
```

**원인:**

- mgmt DNS Zone이 게임 프로젝트의 VPC를 `additional_networks`로 추가하려고 시도
- 그러나 해당 프로젝트에 이미 동일한 도메인(`delabsgames.internal.`)의 DNS Zone이 존재
- GCP에서는 같은 VPC에 동일 DNS 이름의 Zone을 중복 연결할 수 없음

**해결 (2025-12-04 적용):**

`has_own_dns_zone` 플래그 패턴을 사용하여 자체 DNS Zone이 있는 프로젝트 제외:

```hcl
# bootstrap/common.hcl
projects = {
  gcby = {
    project_id       = "gcp-gcby"
    has_own_dns_zone = true  # 자체 DNS Zone 있음 - mgmt DNS Zone에서 제외
    # ...
  }
}
```

```hcl
# bootstrap/12-dns/terragrunt.hcl
additional_networks = [
  for key, project in local.common_vars.locals.projects : project.network_url
  if try(project.has_own_dns_zone, false) == false
]
```

**새 프로젝트 추가 시:**

1. **자체 DNS Zone이 있는 프로젝트**: `has_own_dns_zone = true` 추가
2. **자체 DNS Zone이 없는 프로젝트**: 플래그 생략 또는 `false`

**관련 문서:**

- [작업 이력 (2025-12-04)](../changelog/work_history/2025-12-04.md#session-3-cross-project-psc-redis-연결-및-dns-zone-충돌-해결)

---

## Backend Service 삭제 순서 문제

### resourceInUseByAnotherResource 에러

**증상:**

```text
Error: Error deleting InstanceGroup: googleapi: Error 400: The instance_group resource
'projects/gcp-gcby/zones/us-west1-c/instanceGroups/gcby-gs-ig-c' is already being used by
'projects/gcp-gcby/global/backendServices/gcby-gs-backend', resourceInUseByAnotherResource
```

**원인:**

- Terraform이 삭제 순서를 잘못 계산
- 올바른 순서: Backend Service 업데이트 (backend 제거) → Instance Group 삭제
- 실제 순서: Instance Group 삭제 시도 → 에러
- Terraform Core의 근본적인 제약 (GitHub Issue #6376)
- `local.auto_backends`가 동적으로 생성되어 dependency 추적 불가

**해결:**

**방법 1: cleanup 스크립트 사용 (권장)**

```bash
cd environments/LIVE/gcp-gcby/70-loadbalancers/gs
./cleanup_backends.sh  # Backend에서 Instance Group 자동 제거
terragrunt apply       # 안전하게 apply
```

**방법 2: 수동 제거**

```bash
# Backend Service에서 Instance Group 수동 제거
gcloud compute backend-services remove-backend gcby-gs-backend \
  --instance-group=gcby-gs-ig-c \
  --instance-group-zone=us-west1-c \
  --global \
  --project=gcp-gcby

# 그 다음 apply
terragrunt apply
```

**Jenkins 자동화:**

Jenkins 파이프라인이 Phase 7 apply 전에 cleanup 스크립트를 자동 실행합니다.
- Execute All Phases (all 실행)와 Single Layer (개별 실행) 모두 지원
- 수동 개입 불필요

**cleanup_backends.sh 동작:**

1. terraform.tfvars에서 정의된 instance_groups 파싱
2. Backend Service의 현재 backends 확인
3. Backend에는 있지만 tfvars에 없는 Instance Group 찾기
4. gcloud로 Backend Service에서 자동 제거

**⚠️ 중요: cleanup이 작동하는 조건**

✅ **작동**: terraform.tfvars에서 instance_group을 **직접 제거**
```hcl
# Before
instance_groups = {
  "gcby-gs-ig-a" = { ... }
  "gcby-gs-ig-c" = { ... }  # ← 제거
}
# After
instance_groups = {
  "gcby-gs-ig-a" = { ... }
}
# → cleanup이 gcby-gs-ig-c를 Backend에서 제거
```

❌ **작동 안 함**: VM 삭제로 인한 Instance Group 자동 삭제
```bash
# 1. 50-workloads에서 VM 삭제
# 2. terraform.tfvars에는 instance_group 그대로
# → cleanup: "tfvars에 있으니 유지" (작동 안 함)
# → Terraform: "VM 없으니 Instance Group 삭제"
# → 에러 발생! (Backend에 여전히 붙어있음)

# 해결: terraform.tfvars에서도 instance_group 제거 필요
```

**관련 파일:**

- `environments/LIVE/gcp-gcby/70-loadbalancers/gs/cleanup_backends.sh`
- `proj-default-templet/70-loadbalancers/*/cleanup_backends.sh` (템플릿)
- `environments/LIVE/gcp-gcby/Jenkinsfile` (자동 실행 로직)

**참고:**

- 이것은 Terraform Core의 알려진 제약사항입니다 (해결 불가능)
- cleanup 스크립트는 베스트 프랙티스 조사 결과 도출된 현실적인 해결책입니다
- destroy provisioner는 `for_each` 리소스에서 작동하지 않습니다

---

## terraform.tfvars vs Terragrunt Inputs 우선순위

### terraform.tfvars가 terragrunt inputs를 덮어씀

**증상:**

```text
# terragrunt plan 결과
+ instance_groups = {}  # 빈 맵으로 계획됨
# 또는
No changes. Your infrastructure matches the configuration.
# 실제로는 Instance Group이 생성되지 않음
```

**원인:**

- Terraform은 `*.tfvars` 파일을 **자동 로드**하여 변수 설정
- terragrunt.hcl의 `inputs`로 값을 주입해도 tfvars가 **우선 적용**
- 빈 값(`{}`, `[]`)도 유효한 값으로 간주되어 terragrunt 값 덮어씀

**문제 패턴:**

```hcl
# terraform.tfvars (문제!)
instance_groups = {}  # ❌ terragrunt 주입 값을 덮어씀

# terragrunt.hcl
inputs = {
  instance_groups = dependency.workloads.outputs.instance_groups  # 무시됨!
}
```

**해결:**

terragrunt에서 동적 주입하는 변수는 terraform.tfvars에서 **정의하지 않음**:

```hcl
# terraform.tfvars (올바른 방법)
# ⚠️ instance_groups는 terragrunt.hcl에서 동적으로 주입됨
# terraform.tfvars에서 정의하면 terragrunt inputs를 덮어쓰므로 여기서는 정의하지 않음

backend_protocol  = "HTTP"
backend_port_name = "http"
# ... 다른 변수들
```

**영향받는 변수들 (주의!):**

| 레이어 | 변수 | terragrunt에서 주입 |
|--------|------|-------------------|
| 70-loadbalancers | `instance_groups` | 50-workloads dependency |
| 10-network | `firewall_rules` | common.naming.tfvars 기반 동적 생성 |

**디버그 방법:**

```bash
# terragrunt가 실제로 전달하는 값 확인
cd 70-loadbalancers/www
terragrunt render-json > debug.json
cat debug.json | jq '.inputs.instance_groups'

# terraform이 받는 최종 값 확인
terragrunt plan -out=plan.out
terraform show -json plan.out | jq '.planned_values.root_module.resources[] | select(.type == "google_compute_instance_group")'
```

**관련 문서:**

- [작업 이력 (2025-12-08)](../changelog/work_history/2025-12-08.md)

---

### Instance Group wrongSubnetwork 에러

**증상:**

```text
Error creating InstanceGroup: googleapi: Error 400: Invalid value for field
'resource.network': '...'. The subnetwork resource '...gcby-subnet-private'
is not part of the network resource '...gcby-live-vpc'., invalid
```

또는:

```text
Error adding instances to instance group: googleapi: Error 400:
VM 'gcby-gs01' belongs to subnetwork 'gcby-live-subnet-private'
but instance group expects 'gcby-subnet-private'., wrongSubnetwork
```

**원인:**

- Instance Group이 잘못된 subnet으로 생성됨
- VM은 `{project}-live-subnet-private`에 있지만
- Instance Group은 `{project}-subnet-private` (환경명 빠짐)으로 생성됨

**해결:**

1. **Backend Service에서 Instance Group 연결 해제:**

```bash
gcloud compute backend-services remove-backend {backend-name} \
  --instance-group={ig-name} \
  --instance-group-zone={zone} \
  --global \
  --project={project-id}
```

2. **잘못된 Instance Groups 삭제:**

```bash
gcloud compute instance-groups unmanaged delete {ig-name} \
  --zone={zone} \
  --project={project-id} \
  --quiet
```

3. **올바른 subnet으로 재생성 (terragrunt apply):**

```bash
cd 70-loadbalancers/gs
terragrunt apply
```

**예방:**

- `common.naming.tfvars`의 subnet 이름 규칙 확인
- `{project_name}-{environment}-subnet-{type}` 형식 준수

**관련 문서:**

- [작업 이력 (2025-12-08)](../changelog/work_history/2025-12-08.md)

---

**다른 문제?**

- [State 문제](./state-issues.md)
- [네트워크 문제](./network-issues.md)
- [GitHub Issues](https://github.com/your-org/terraform-gcp-infra/issues)
