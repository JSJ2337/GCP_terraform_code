# 부트스트랩 - Terraform 상태 관리

이 디렉토리는 Terraform 상태를 저장하기 위한 관리용 프로젝트와 GCS 버킷을 생성합니다.

## 목적

- **관리용 GCP 프로젝트**: `delabs-system-mgmt`
- **상태 저장 버킷**: `delabs-terraform-state-prod`
- 모든 다른 프로젝트의 Terraform 상태를 여기에 중앙 관리

## 중요 사항

⚠️ **이 프로젝트의 상태는 로컬에 저장됩니다**
- `terraform.tfstate` 파일이 로컬에 생성됨
- Git에 커밋하거나 안전한 곳에 백업 필요
- 이것은 부트스트랩 문제 해결을 위한 의도된 설계

## 사용 방법

### 1. 초기 배포

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

### 2. 배포 후 확인

```bash
# 프로젝트 확인
gcloud projects describe delabs-system-mgmt

# 버킷 확인
gsutil ls -L gs://delabs-terraform-state-prod
```

### 3. 다른 프로젝트에서 사용

다른 프로젝트의 `backend.tf`:

```hcl
terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "proj-game-a/00-project"
  }
}
```

## 상태 파일 백업

로컬 `terraform.tfstate` 파일 백업 방법:

### 옵션 1: Git에 암호화해서 저장
```bash
# git-crypt 또는 sops 사용
git-crypt init
git-crypt add-gpg-user <your-key>
```

### 옵션 2: 안전한 위치에 수동 백업
```bash
# 주기적으로 복사
cp terraform.tfstate ~/safe-backup/bootstrap-$(date +%Y%m%d).tfstate
```

### 옵션 3: 다른 GCS 버킷에 수동 업로드
```bash
gsutil cp terraform.tfstate gs://your-backup-bucket/bootstrap/
```

## 리소스 삭제 시 주의

⚠️ 이 프로젝트를 삭제하면 모든 프로젝트의 상태가 손실됩니다!

- `deletion_policy = "PREVENT"` 설정으로 실수 방지
- 버킷도 `force_destroy = false`로 보호

## 디렉토리 구조

```
bootstrap/
├── main.tf              # 프로젝트 및 버킷 정의
├── variables.tf         # 변수 정의
├── terraform.tfvars     # 실제 값
├── outputs.tf           # 출력값
├── terraform.tfstate    # ⚠️ 로컬 상태 (백업 필요!)
└── README.md            # 이 파일
```

## 버킷 설정

- **버전 관리**: 활성화 (최근 10개 버전 보관)
- **수명 주기**: 30일 지난 버전 자동 삭제
- **액세스**: 버킷 수준의 통합 액세스
- **위치**: US (다중 지역)
