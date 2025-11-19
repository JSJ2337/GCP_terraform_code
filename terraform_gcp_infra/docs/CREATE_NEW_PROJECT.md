# 신규 프로젝트 생성 가이드

이 문서는 `proj-default-templet`을 기반으로 신규 GCP 프로젝트를 생성하는 방법을 설명합니다.

## 📋 목차

- [개요](#개요)
- [사전 요구사항](#사전-요구사항)
- [방법 1: Jenkins를 통한 생성 (권장)](#방법-1-jenkins를-통한-생성-권장)
- [방법 2: 로컬에서 스크립트 실행](#방법-2-로컬에서-스크립트-실행)
- [생성 후 작업](#생성-후-작업)
- [트러블슈팅](#트러블슈팅)

---

## 개요

신규 프로젝트 생성 시 다음 작업이 자동으로 수행됩니다:

1. ✅ `proj-default-templet` 디렉토리 복사
2. ✅ 필수 설정 파일 치환:
   - `root.hcl`: Terraform state 설정, GCP org/billing 정보
   - `common.naming.tfvars`: 프로젝트 ID, 이름, 조직, 리전
   - `Jenkinsfile`: TG_WORKING_DIR 경로
   - `10-network/terraform.tfvars`: 서브넷 이름
   - `50-workloads/terraform.tfvars`: 서브넷 self-link 경로
3. ✅ Git 브랜치 생성 및 커밋
4. ✅ Pull Request 자동 생성 (선택)

---

## 사전 요구사항

### 필수 정보

신규 프로젝트 생성 전에 다음 정보를 준비하세요:

| 항목 | 설명 | 예시 |
|------|------|------|
| **PROJECT_ID** | GCP 프로젝트 ID (6-30자, 소문자/숫자/하이픈) | `jsj-game-n` |
| **PROJECT_NAME** | 프로젝트 이름 (리소스 네이밍용) | `game-n` |
| **ORGANIZATION** | 조직명 (리소스 접두어) | `jsj` |
| **ENVIRONMENT** | 배포 환경 (LIVE/QA/STG) | `LIVE` |
| **REGION_PRIMARY** | 주 리전 | `asia-northeast3` (서울) |
| **REGION_BACKUP** | 백업 리전 | `asia-northeast1` (도쿄) |

### 고정 설정값 (configs/defaults.yaml)

다음 값들은 `configs/defaults.yaml`에 정의되어 있습니다:

- GCP Organization ID: `REDACTED_ORG_ID`
- Billing Account: `REDACTED_BILLING_ACCOUNT`
- Remote State Bucket: `jsj-terraform-state-prod`
- Remote State Project: `jsj-system-mgmt`

### Jenkins 사용 시 추가 요구사항

**방법 1 (Jenkins)을 사용하려면 다음이 필요합니다:**

1. ✅ **GitHub Personal Access Token** 생성
2. ✅ **Jenkins Credential** 등록 (ID: `github-pat`)
3. ⚠️ **gh CLI** 설치 (PR 자동 생성 시 필요, 선택사항)

**상세 설정 방법:**
- 📖 [Jenkins GitHub Credential 설정 가이드](./JENKINS_GITHUB_SETUP.md) 참고

> **참고**: 로컬 스크립트 사용 시 (방법 2)는 Credential 설정 불필요

---

## 방법 1: Jenkins를 통한 생성 (권장)

### 1. Jenkins Job 설정

Jenkins에 `create-terraform-project` Job을 생성합니다:

**Job 설정:**
- **Type**: Pipeline
- **Pipeline script from SCM**: Git
- **Script Path**: `terraform_gcp_infra/Jenkinsfile.create-project`
- **Branch**: `main`

### 2. Job 실행

1. Jenkins에서 `create-terraform-project` Job 선택
2. **Build with Parameters** 클릭
3. 파라미터 입력:

   ```
   PROJECT_ID: jsj-game-n
   PROJECT_NAME: game-n
   ORGANIZATION: jsj
   ENVIRONMENT: LIVE (드롭다운)
   REGION_PRIMARY: asia-northeast3 (드롭다운)
   REGION_BACKUP: asia-northeast1 (드롭다운)
   CREATE_PR: ✅ (체크)
   ```

4. **Build** 클릭

### 3. 실행 결과 확인

Jenkins Pipeline이 다음 단계를 순차적으로 수행합니다:

```
✅ Checkout
✅ Validate Parameters
✅ Check Duplicate
✅ Install Dependencies
✅ Create Project
✅ Push to Remote
✅ Create Pull Request
```

성공 시 자동으로 Pull Request가 생성됩니다.

---

## 방법 2: 로컬에서 스크립트 실행

### 1. 스크립트 실행

터미널에서 다음 명령어를 실행합니다:

```bash
cd terraform_gcp_infra

bash scripts/create_project.sh \
    jsj-game-n \
    game-n \
    jsj \
    LIVE \
    asia-northeast3 \
    asia-northeast1
```

**사용법:**
```bash
./scripts/create_project.sh <PROJECT_ID> <PROJECT_NAME> <ORGANIZATION> <ENVIRONMENT> <REGION_PRIMARY> [REGION_BACKUP]
```

**환경 옵션:**
- `LIVE`: 운영 환경 (environments/LIVE)
- `QA`: QA 환경 (environments/QA)
- `STG`: 스테이징 환경 (environments/STG)

### 2. PR 생성 여부 확인

스크립트 실행 중 다음 메시지가 나타납니다:

```
Pull Request 생성 여부를 확인합니다...
PR을 생성하시겠습니까? (y/N):
```

- **y**: gh CLI를 사용하여 자동으로 PR 생성
- **N**: 수동으로 브랜치 푸시 및 PR 생성

### 3. 수동 PR 생성 (선택)

PR을 자동 생성하지 않은 경우:

```bash
# 브랜치 푸시
git push -u origin feature/create-project-jsj-game-n

# GitHub에서 수동으로 PR 생성
# 또는 gh CLI 사용
gh pr create \
    --title "[Infra] jsj-game-n 프로젝트 생성" \
    --body "신규 프로젝트 생성" \
    --base main
```

---

## 생성 후 작업

### 1. Pull Request 리뷰 및 머지

1. GitHub에서 생성된 PR 확인
2. 변경 내역 검토:
   - `root.hcl`
   - `common.naming.tfvars`
   - `Jenkinsfile`
   - `10-network/terraform.tfvars`
   - `50-workloads/terraform.tfvars`
3. 필요 시 추가 수정 (선택사항):
   - VM 인스턴스 이름 변경
   - Instance Group 이름 변경
   - Database/Cache 설정 조정
4. PR 승인 및 `main` 브랜치에 머지

### 2. Jenkins 배포 Job 생성

새 프로젝트를 배포하기 위한 Jenkins Job을 생성합니다.

#### 옵션 A: 프로젝트별 전용 Job 생성

**Job 이름**: `terraform-deploy-jsj-game-n`

**Pipeline 설정:**
```groovy
pipeline {
    script path: terraform_gcp_infra/environments/LIVE/jsj-game-n/Jenkinsfile
}
```

#### 옵션 B: 파라미터화된 단일 Job 사용

기존에 파라미터화된 배포 Job이 있다면, `PROJECT_ID` 파라미터에 `jsj-game-n`을 입력하여 사용합니다.

### 3. 초기 인프라 배포

배포는 **반드시 순서대로** 수행해야 합니다:

```
1. 00-project       # GCP 프로젝트 생성 및 API 활성화
   ↓
2. 10-network       # VPC 및 서브넷 생성
   ↓
3. 20-storage       # Cloud Storage 버킷 생성
   ↓
4. 30-security      # IAM 및 보안 설정
   ↓
5. 40-observability # 모니터링 및 로깅
   ↓
6. 50-workloads     # VM 인스턴스 생성
   ↓
7. 60-database      # Cloud SQL 생성
   ↓
8. 65-cache         # Memorystore Redis 생성
   ↓
9. 70-loadbalancers # 로드밸런서 생성
```

**Jenkins 배포 단계:**

각 레이어별로 다음 작업을 수행합니다:

1. **Plan 실행** (ACTION=plan, TARGET_LAYER=00-project)
   - 변경 사항 검토
2. **Apply 실행** (ACTION=apply, TARGET_LAYER=00-project)
   - 승인 대기 → 승인 → 배포
3. **다음 레이어로 진행**

**전체 스택 배포 (권장하지 않음):**
- `TARGET_LAYER=all`로 한 번에 배포 가능하나, 문제 발생 시 디버깅이 어려움
- 최초 배포는 레이어별로 수행 권장

---

## 트러블슈팅

### 문제 1: "프로젝트가 이미 존재합니다"

**원인:** 동일한 PROJECT_ID로 프로젝트가 이미 생성됨

**해결:**
```bash
# 기존 프로젝트 삭제 (주의!)
rm -rf terraform_gcp_infra/environments/LIVE/jsj-game-n

# 또는 다른 PROJECT_ID 사용
```

### 문제 2: "yq가 설치되어 있지 않습니다"

**원인:** YAML 파서 `yq`가 시스템에 설치되지 않음

**해결:**
```bash
# Ubuntu/Debian
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# macOS
brew install yq
```

**또는**: 스크립트는 `yq` 없이도 기본값으로 동작합니다.

### 문제 3: "gh CLI가 설치되어 있지 않습니다"

**원인:** GitHub CLI가 설치되지 않아 PR 자동 생성 불가

**해결:**
```bash
# Ubuntu/Debian
sudo apt install gh

# macOS
brew install gh

# 인증
gh auth login
```

**또는**: 수동으로 브랜치를 푸시하고 GitHub에서 PR 생성

### 문제 4: Git 푸시 실패 (권한 없음)

**원인:** Git 인증 설정 필요

**해결:**
```bash
# SSH 키 설정 확인
ssh -T git@github.com

# 또는 Personal Access Token 사용
git remote set-url origin https://YOUR_TOKEN@github.com/your-org/your-repo.git
```

### 문제 5: sed 명령어 에러 (macOS)

**원인:** macOS의 BSD sed와 Linux의 GNU sed 차이

**해결:**
```bash
# macOS에서 GNU sed 설치
brew install gnu-sed

# PATH에 추가
export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
```

---

## 추가 정보

### 수동으로 수정이 필요할 수 있는 파일

자동 치환되지 않는 선택적 설정들:

1. **50-workloads/terraform.tfvars**
   - VM 인스턴스 이름: `jsj-lobby-01`, `jsj-web-01` 등
   - Instance Group 이름: `jsj-web-ig-a` 등

2. **60-database/terraform.tfvars**
   - Read replica 이름: `default-templet-mysql-read-1`

3. **65-cache/terraform.tfvars**
   - Display name: `default-templet prod redis`
   - Labels: `app = "default-templet"`

4. **20-storage/terraform.tfvars**
   - CORS origin (도메인)

5. **각 레이어의 README.md**
   - 예시 경로 및 설명

### 관련 문서

- [Terragrunt 사용 가이드](../README.md)
- [Jenkins Pipeline 설정](./JENKINS_SETUP.md)
- [네트워크 구성](../10-network/README.md)
- [워크로드 배포](../50-workloads/README.md)

---

## 문의

문제가 발생하거나 질문이 있으시면:
- GitHub Issues 생성
- DevOps 팀에 문의
