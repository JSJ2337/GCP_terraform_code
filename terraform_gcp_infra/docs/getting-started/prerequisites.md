# 사전 요구사항

시작하기 전에 다음 도구와 권한이 필요합니다.

## 필수 도구

### 1. Terraform

```bash
# 버전 확인
terraform version
# Required: >= 1.6 (권장: 1.10+ / 최신: 1.13.5)
```

**설치**:

- macOS: `brew install terraform`
- Linux: [공식 다운로드](https://www.terraform.io/downloads)
- Windows: Chocolatey `choco install terraform`

### 2. Terragrunt

```bash
# 버전 확인
terragrunt --version
# Required: >= 0.93
```

**설치**:

- macOS: `brew install terragrunt`
- Linux: [GitHub Releases](https://github.com/gruntwork-io/terragrunt/releases)
- WSL: 절대 경로 사용 (예: `/mnt/d/jsj_wsl_data/terragrunt_linux_amd64`)

**Bash Alias 설정** (선택):

```bash
echo 'alias terragrunt="/mnt/d/jsj_wsl_data/terragrunt_linux_amd64"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Google Cloud SDK

```bash
# 버전 확인
gcloud --version
```

**설치**:

- [공식 설치 가이드](https://cloud.google.com/sdk/docs/install)

## 필수 권한

### GCP 인증

```bash
# Application Default Credentials 설정
gcloud auth application-default login

# 프로젝트 설정 (Bootstrap 프로젝트)
gcloud config set project jsj-system-mgmt

# Quota Project 설정 (중요!)
gcloud auth application-default set-quota-project jsj-system-mgmt
```

### Billing Account 확인

```bash
# Billing Account ID 조회
gcloud billing accounts list

# 출력 예시:
# ACCOUNT_ID            NAME                OPEN  MASTER_ACCOUNT_ID
# 01076D-327AD5-FC8922  My Billing Account  True
```

## 권한 요구사항

### 조직이 있는 경우

- **조직 레벨**:
  - `roles/resourcemanager.projectCreator` (프로젝트 생성)
  - `roles/billing.user` (청구 계정 연결)
  - `roles/editor` (리소스 관리)

### 조직이 없는 경우

- **프로젝트별 수동 생성** 필요
- 각 프로젝트에 `roles/editor` 권한 부여
- Billing Account 수동 연결

## 저장소 준비

```bash
# 저장소 클론
git clone <repository-url>
cd terraform_gcp_infra

# 디렉터리 구조 확인
ls -la
```

## 다음 단계

✅ 모든 사전 요구사항이 준비되었다면:

- [Bootstrap 설정하기](./bootstrap-setup.md)

## 트러블슈팅

### WSL 환경 이슈

- **문제**: `setsockopt: operation not permitted` 오류
- **해결**: Linux VM 또는 컨테이너에서 실행 권장
- **대안**: 최신 WSL2 커널로 업데이트

### 권한 오류

- **문제**: `Permission denied` 오류
- **해결**:
  1. ADC 재설정: `gcloud auth application-default login`
  2. Quota Project 설정: `gcloud auth application-default set-quota-project jsj-system-mgmt`

---

**관련 문서**:

- [Bootstrap 설정](./bootstrap-setup.md)
- [트러블슈팅 가이드](../troubleshooting/common-errors.md)
