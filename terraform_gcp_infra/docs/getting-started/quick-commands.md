# 자주 쓰는 명령어

일상적인 작업에 필요한 명령어 치트시트입니다.

## Terragrunt 기본 명령어

### 단일 레이어 실행
```bash
cd environments/LIVE/jsj-game-k/00-project

# 초기화
terragrunt init --non-interactive

# 계획
terragrunt plan

# 적용
terragrunt apply

# 삭제
terragrunt destroy
```

### 전체 스택 실행
```bash
cd environments/LIVE/jsj-game-k

# 전체 Plan
terragrunt run --all plan

# 전체 Apply
terragrunt run --all apply

# 전체 Destroy (위험!)
terragrunt run --all destroy
```

### 특정 레이어만 실행
```bash
cd environments/LIVE/jsj-game-k

# 00-project만 Plan
terragrunt run --queue-include-dir '00-project' --all plan

# 10-network, 20-storage만 Apply
terragrunt run --queue-include-dir '10-network' \
               --queue-include-dir '20-storage' \
               --all apply
```

## State 관리

### State 조회
```bash
# State 리스트
terragrunt state list

# 특정 리소스 확인
terragrunt state show 'google_compute_network.main'

# State 전체 출력
terragrunt state pull | jq
```

### State 이동
```bash
# 리소스 이름 변경
terragrunt state mv 'old_name' 'new_name'

# 모듈 구조 변경
terragrunt state mv \
  'module.old_bucket' \
  'module.storage.module.buckets["assets"]'
```

### State 제거
```bash
# State에서만 제거 (리소스는 유지)
terragrunt state rm 'google_compute_instance.test'
```

## Output 조회

### 현재 레이어 Output
```bash
# 모든 output
terragrunt output

# JSON 형식
terragrunt output -json | jq

# 특정 output만
terragrunt output vpc_id
```

### 다른 레이어 Output 참조
```bash
# 네트워크 레이어 Output
cd ../10-network
terragrunt output -json | jq '.vpc_name.value'

# 프로젝트 레이어 Output
cd ../00-project
terragrunt output project_id
```

## 코드 관리

### 포맷팅
```bash
# 전체 포맷팅
cd terraform_gcp_infra
terraform fmt -recursive

# 특정 디렉터리만
cd modules/gcs-bucket
terraform fmt
```

### 검증
```bash
# Terraform 문법 검증
terraform validate

# Terragrunt 설정 검증
terragrunt validate-all
```

## GCP 명령어

### 프로젝트 관리
```bash
# 프로젝트 리스트
gcloud projects list

# 프로젝트 상세
gcloud projects describe jsj-game-k

# 활성 프로젝트 설정
gcloud config set project jsj-game-k
```

### 리소스 조회
```bash
# VPC 네트워크
gcloud compute networks list --project=jsj-game-k

# 서브넷
gcloud compute networks subnets list --project=jsj-game-k

# VM 인스턴스
gcloud compute instances list --project=jsj-game-k

# Cloud SQL
gcloud sql instances list --project=jsj-game-k

# Redis
gcloud redis instances list --region=asia-northeast3 --project=jsj-game-k

# Load Balancer
gcloud compute forwarding-rules list --project=jsj-game-k
```

### API 관리
```bash
# 활성화된 API 확인
gcloud services list --enabled --project=jsj-game-k

# API 활성화
gcloud services enable compute.googleapis.com \
    servicenetworking.googleapis.com \
    sqladmin.googleapis.com \
    --project=jsj-game-k
```

### Service Account
```bash
# SA 리스트
gcloud iam service-accounts list --project=jsj-game-k

# SA 상세
gcloud iam service-accounts describe \
    jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com

# Key 생성
gcloud iam service-accounts keys create key.json \
    --iam-account=jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com
```

## State 버킷 관리

### 버킷 조회
```bash
# State 버킷 리스트
gsutil ls gs://jsj-terraform-state-prod/

# 특정 프로젝트 State
gsutil ls gs://jsj-terraform-state-prod/jsj-game-k/

# State 파일 내용
gsutil cat gs://jsj-terraform-state-prod/jsj-game-k/00-project/default.tfstate | jq
```

### 버킷 백업
```bash
# Bootstrap State 백업
cd bootstrap
gsutil cp terraform.tfstate gs://jsj-terraform-state-prod/bootstrap/backup-$(date +%Y%m%d).tfstate

# 전체 버킷 백업
gsutil -m rsync -r \
    gs://jsj-terraform-state-prod/ \
    gs://jsj-terraform-state-backup/
```

## 디버깅

### Terragrunt 디버그 로그
```bash
# 상세 로그 활성화
export TF_LOG=DEBUG
export TERRAGRUNT_LOG_LEVEL=debug

terragrunt plan

# 로그 비활성화
unset TF_LOG
unset TERRAGRUNT_LOG_LEVEL
```

### Terraform 디버그
```bash
# 상세 로그
TF_LOG=DEBUG terraform plan

# 특정 리소스만 타겟팅
terragrunt plan -target=google_compute_network.main

# Refresh 없이 Plan
terragrunt plan -refresh=false
```

## 성능 최적화

### 병렬 실행
```bash
# 병렬도 조정 (기본: 10)
terragrunt plan -parallelism=20
terragrunt apply -parallelism=20
```

### 캐시 정리
```bash
# Terragrunt 캐시 정리
find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;

# Terraform 캐시 정리
find . -type d -name ".terraform" -prune -exec rm -rf {} \;

# 플랜 파일 정리
find . -type f -name "tfplan*" -delete
```

## 비상 상황

### State Lock 해제
```bash
# Lock ID 확인 (에러 메시지에서)
terragrunt force-unlock <LOCK_ID>
```

### 리소스 Import
```bash
# 기존 GCP 리소스를 State에 추가
terragrunt import google_compute_network.main projects/jsj-game-k/global/networks/vpc-main
```

### 특정 리소스만 재생성
```bash
# Taint (다음 apply 시 재생성)
terragrunt taint google_compute_instance.web

# Untaint
terragrunt untaint google_compute_instance.web
```

## Git 명령어

### 일반 워크플로우
```bash
# 변경 사항 확인
git status
git diff

# 커밋
git add .
git commit -m "feat: add new module"

# 푸시
git push origin main
```

### 브랜치 관리
```bash
# 브랜치 생성
git checkout -b feature/new-module

# 브랜치 전환
git checkout main

# 브랜치 병합
git merge feature/new-module
```

## 유용한 조합

### 전체 인프라 상태 확인
```bash
#!/bin/bash
# check-infra.sh

PROJECT="jsj-game-k"

echo "=== VPC ==="
gcloud compute networks list --project=$PROJECT

echo "=== VMs ==="
gcloud compute instances list --project=$PROJECT

echo "=== Cloud SQL ==="
gcloud sql instances list --project=$PROJECT

echo "=== Redis ==="
gcloud redis instances list --region=asia-northeast3 --project=$PROJECT

echo "=== Load Balancers ==="
gcloud compute forwarding-rules list --project=$PROJECT
```

### 비용 확인
```bash
# 프로젝트 비용 (최근 30일)
gcloud billing projects describe jsj-game-k

# 상세 비용 리포트 (Cloud Console)
# https://console.cloud.google.com/billing/
```

### 보안 스캔
```bash
# tfsec 설치
brew install tfsec

# 보안 스캔
cd terraform_gcp_infra
tfsec .

# 특정 모듈만
tfsec modules/cloudsql-mysql/
```

---

**관련 문서**:
- [Terragrunt 사용법](../guides/terragrunt-usage.md)
- [트러블슈팅](../troubleshooting/common-errors.md)
- [State 관리](../architecture/state-management.md)
