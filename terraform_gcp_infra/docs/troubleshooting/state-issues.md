# State 문제 해결

Terraform State 관련 문제 해결 가이드입니다.

## State Lock 문제

### Lock 걸림
```bash
# Lock 강제 해제
terragrunt force-unlock <LOCK_ID>

# GCS에서 직접 삭제
gsutil rm gs://jsj-terraform-state-prod/path/to/default.tflock
```

### Lock 타임아웃
```bash
# 타임아웃 연장
terragrunt plan -lock-timeout=10m
```

## State 손상

### State 백업에서 복원
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
cd bootstrap
cp ~/backup/bootstrap-20251112.tfstate terraform.tfstate

# 또는 GCS에서
gsutil cp gs://jsj-terraform-state-prod/bootstrap/default.tfstate terraform.tfstate
```

## State 불일치

### Refresh
```bash
# State 새로고침
terragrunt plan -refresh-only
terragrunt apply -refresh-only
```

### Import
```bash
# 기존 리소스를 State에 추가
terragrunt import google_compute_network.main \
    projects/jsj-game-k/global/networks/vpc-main
```

## State 이동

### 리소스 이름 변경
```bash
terragrunt state mv 'old_name' 'new_name'
```

### 모듈 구조 변경
```bash
terragrunt state mv \
  'module.old_bucket' \
  'module.storage.module.buckets["assets"]'
```

### State 제거
```bash
# State에서만 제거 (리소스는 유지)
terragrunt state rm 'google_compute_instance.test'
```

## 참고

상세한 내용은 [일반적인 오류](./common-errors.md)의 State 섹션을 참조하세요.

---

**관련 문서**:
- [일반적인 오류](./common-errors.md)
- [State 관리 아키텍처](../architecture/state-management.md)
