# 일반적인 오류 해결

Terraform/Terragrunt 사용 시 자주 발생하는 오류와 해결 방법입니다.

## State 관련 오류

### 1. "storage: bucket doesn't exist"

**증상**:
```
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
```
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
```
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

## 권한 관련 오류

### 4. "Permission denied"

**증상**:
```
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
gcloud projects add-iam-policy-binding jsj-game-k \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/editor"
```

### 5. Billing Account 권한 오류

**증상**:
```
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
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"
```

## API 활성화 오류

### 6. "API not enabled"

**증상**:
```
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

### 7. "Service Networking API" 타이밍 이슈

**증상**:
```
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

### 8. "resource not found"

**증상**:
```
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

### 9. "already exists"

**증상**:
```
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

### 10. "Unreadable module directory"

**증상**:
```
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

### 11. "Missing required GCS remote state configuration"

**증상**:
```
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

### 12. WSL "setsockopt: operation not permitted"

**증상**:
```
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

### 13. Private Service Connect 실패

**증상**:
```
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

### 14. 방화벽 규칙 충돌

**증상**:
```
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

### 15. 변수 타입 불일치

**증상**:
```
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

## 긴급 복구

### State 복원
```bash
# Versioning된 State 리스트
gsutil ls -la gs://jsj-terraform-state-prod/jsj-game-k/00-project/

# 이전 버전 복원
gsutil cp \
    gs://jsj-terraform-state-prod/jsj-game-k/00-project/default.tfstate#1234567890 \
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
