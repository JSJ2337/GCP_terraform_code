# Terragrunt CI/CD Pipeline 가이드

Jenkins를 사용한 Terragrunt 자동화 Pipeline 사용 방법을 설명합니다.

## 목차

- [개요](#개요)
- [Pipeline 구조](#pipeline-구조)
- [안전 장치](#안전-장치)
- [사용 방법](#사용-방법)
- [파라미터 설명](#파라미터-설명)
- [실행 시나리오](#실행-시나리오)
- [승인 프로세스](#승인-프로세스)
- [문제 해결](#문제-해결)
- [GCP Credentials 설정](#gcp-credentials-설정)

---

## 개요

### 목적

Terraform/Terragrunt 코드 변경 시 안전하게 인프라를 배포할 수 있는 자동화 Pipeline을 제공합니다.

### 주요 특징

```
✅ 승인 없이는 절대 Apply 안 됨
✅ Plan 결과를 반드시 확인
✅ 개별 레이어 선택 가능
✅ 전체 스택 또는 단일 레이어 실행
✅ 의존성 순서 자동 처리 (Terragrunt)
✅ 30분 승인 타임아웃
```

---

## Pipeline 구조

### Terragrunt 프로젝트 구조

```
terraform_gcp_infra/
└── environments/LIVE/jsj-game-f/
    ├── terragrunt.hcl          # Remote state 설정
    ├── common.naming.tfvars    # 공통 변수
    ├── 00-project/             # GCP 프로젝트 기본 설정
    ├── 10-network/             # VPC, 서브넷, 방화벽
    ├── 20-storage/             # GCS 버킷
    ├── 30-security/            # IAM, 보안 정책
    ├── 40-observability/       # 로깅, 모니터링
    ├── 50-workloads/           # GCE 인스턴스, MIG
    ├── 60-database/            # Cloud SQL
    ├── 65-cache/               # Memorystore (Redis)
    └── 70-loadbalancer/        # Load Balancer
```

### 레이어 의존성

각 레이어는 이전 레이어에 의존합니다:

```
00-project (기본)
    ↓
10-network (VPC 필요)
    ↓
20-storage (프로젝트, VPC 필요)
    ↓
30-security (IAM, 보안)
    ↓
40-observability (모니터링)
    ↓
50-workloads (GCE 등)
    ↓
60-database (Cloud SQL)
    ↓
65-cache (Redis)
    ↓
70-loadbalancer (LB)
```

**전체 스택 실행 시:** Terragrunt가 의존성 순서대로 자동 실행합니다.

---

## 안전 장치

### 1. 수동 승인 단계

**Apply 또는 Destroy 실행 전 반드시 승인 필요:**

```
Terragrunt Plan 실행 (자동)
    ↓
Plan 결과 출력
    ↓
⏸️  승인 대기 (30분 타임아웃)
    ↓
수동 승인 클릭
    ↓
Terragrunt Apply 실행
```

### 2. 승인자 제한

```groovy
submitter: 'admin'  // admin 사용자만 승인 가능
```

Jenkins 사용자 관리에서 admin 권한을 가진 사용자만 인프라 변경을 승인할 수 있습니다.

### 3. 타임아웃

```groovy
timeout(time: 30, unit: 'MINUTES')
```

30분 내에 승인하지 않으면 자동으로 빌드가 취소됩니다.

### 4. Plan만 실행 가능

`ACTION: plan`을 선택하면 승인 단계 없이 Plan만 확인 가능:
- 인프라 변경 없음
- 안전하게 변경사항 확인
- 언제든지 실행 가능

---

## 사용 방법

### 기본 흐름

1. **Jenkins 대시보드 접속**
   ```
   http://localhost:8080
   또는
   https://your-ngrok-url.ngrok-free.app
   ```

2. **jsj-terraform-pipeline** Job 클릭

3. **Build with Parameters** 클릭

4. **파라미터 선택**
   - ACTION: `plan`, `apply`, 또는 `destroy`
   - TARGET_LAYER: 실행할 레이어 선택

5. **Build** 버튼 클릭

6. **진행 상황 모니터링**
   - Build History에서 진행 중인 빌드 클릭
   - Console Output에서 실시간 로그 확인

7. **승인 (apply/destroy 시)**
   - Plan 결과 확인
   - 승인 버튼 클릭
   - Apply 실행 확인

---

## 파라미터 설명

### ACTION (작업 선택)

| 값 | 설명 | 승인 필요 | 인프라 변경 |
|----|------|-----------|------------|
| **plan** | Plan만 실행 | ❌ 불필요 | ❌ 없음 |
| **apply** | Plan → 승인 → Apply | ✅ 필수 | ✅ 있음 |
| **destroy** | 승인 → Destroy | ✅ 필수 | ✅ 삭제 |

**권장:**
- 처음에는 항상 `plan`으로 시작
- Plan 결과 확인 후 `apply` 실행

### TARGET_LAYER (레이어 선택)

| 값 | 설명 | 실행 범위 |
|----|------|----------|
| **all** | 전체 스택 | 00~70 모든 레이어 (의존성 순서) |
| **00-project** | 프로젝트 기본 설정 | 프로젝트, API 활성화 |
| **10-network** | 네트워크 | VPC, 서브넷, 방화벽 |
| **20-storage** | 스토리지 | GCS 버킷 |
| **30-security** | 보안 | IAM, 보안 정책 |
| **40-observability** | 관측성 | 로깅, 모니터링 |
| **50-workloads** | 워크로드 | GCE, MIG |
| **60-database** | 데이터베이스 | Cloud SQL |
| **65-cache** | 캐시 | Memorystore Redis |
| **70-loadbalancer** | 로드밸런서 | LB, 백엔드 |

**주의:**
- `all` 선택 시 모든 레이어가 순서대로 실행됩니다
- 처음 배포 시에는 반드시 `all` 또는 순서대로 실행
- 이후 특정 레이어만 수정 가능

---

## 실행 시나리오

### 시나리오 1: Plan만 확인 (안전)

**목적:** 변경사항만 확인하고 싶을 때

**단계:**
1. Jenkins → **Build with Parameters**
2. 선택:
   ```
   ACTION: plan
   TARGET_LAYER: all (또는 특정 레이어)
   ```
3. **Build** 클릭
4. Console Output에서 Plan 결과 확인
5. **자동 완료** (승인 불필요)

**결과:**
- ✅ 변경사항 확인 가능
- ❌ 인프라 변경 없음
- ⏱️ 약 2-5분 소요

---

### 시나리오 2: 네트워크만 배포

**목적:** 네트워크 레이어만 수정하고 싶을 때

**단계:**
1. **먼저 Plan 확인:**
   ```
   ACTION: plan
   TARGET_LAYER: 10-network
   ```

2. **Plan 결과 확인 후 Apply:**
   ```
   ACTION: apply
   TARGET_LAYER: 10-network
   ```

3. **승인 대기:**
   - Pipeline이 멈춤
   - 승인 메시지 표시:
     ```
     ⚠️  인프라 변경 승인 필요 ⚠️

     Action: APPLY
     Target: 10-network
     Branch: 433_code
     Commit: 1372147...

     위 Plan을 검토한 후 승인하시겠습니까?

     [ ✅ 승인 (Apply 실행) ]
     ```

4. **승인 클릭**
5. Apply 실행 및 완료 확인

**결과:**
- ✅ 네트워크 레이어만 변경
- ✅ 다른 레이어는 영향 없음

---

### 시나리오 3: 전체 스택 배포

**목적:** 처음부터 모든 인프라 배포

**단계:**
1. **전체 Plan 확인:**
   ```
   ACTION: plan
   TARGET_LAYER: all
   ```

2. **전체 Apply:**
   ```
   ACTION: apply
   TARGET_LAYER: all
   ```

3. **승인:**
   - 전체 스택에 대한 변경사항 확인
   - ⚠️ **매우 신중하게 검토!**
   - 승인 클릭

4. **의존성 순서대로 실행:**
   ```
   00-project → 10-network → 20-storage → ...
   ```

**소요 시간:**
- Plan: 약 5-10분
- Apply: 약 20-40분 (레이어 개수에 따라)

---

### 시나리오 4: GitHub Push 후 자동 실행

**현재 동작:**

```bash
git push origin 433_code
```

→ Jenkins 자동 시작
→ **기본 파라미터로 실행** (plan + all)
→ Plan만 확인, 인프라 변경 없음!

**의도:**
- Push 시 자동으로 Plan을 확인
- 변경사항이 있는지 알림
- 실제 Apply는 수동으로 실행

---

## 승인 프로세스

### 승인 화면

Pipeline이 승인 대기 중일 때:

```
Pipeline 진행 중...
    ↓
[🛑 Manual Approval 🛑] 단계에서 멈춤
    ↓
화면에 표시:
┌─────────────────────────────────────┐
│ ⚠️  인프라 변경 승인 필요 ⚠️          │
│                                     │
│ Action: APPLY                       │
│ Target: 10-network                  │
│ Branch: 433_code                    │
│ Commit: 1372147...                  │
│                                     │
│ 위 Plan을 검토한 후 승인하시겠습니까?│
│                                     │
│ [ ✅ 승인 (Apply 실행) ] [ ❌ 취소 ] │
└─────────────────────────────────────┘
```

### 승인 시 확인사항

✅ **Plan 결과 확인:**
- 리소스 추가/변경/삭제 개수
- 예상치 못한 변경 없는지
- 중요 리소스 삭제 없는지

✅ **브랜치 확인:**
- 올바른 브랜치에서 실행 중인지
- 최신 커밋인지

✅ **Target 확인:**
- 의도한 레이어가 맞는지
- `all`이면 전체 스택 변경됨

### 승인 거부 시

**Abort** 버튼 클릭 또는 30분 타임아웃:
- Pipeline 취소
- 인프라 변경 없음
- 다시 실행 가능

---

## 문제 해결

### 문제 1: GCP 인증 실패

**증상:**
```
Error: google: could not find default credentials
```

**원인:** GCP Service Account 인증 정보 없음

**해결:** [GCP Credentials 설정](#gcp-credentials-설정) 참조

---

### 문제 2: Terragrunt Lock 파일 충돌

**증상:**
```
Error: Failed to acquire state lock
```

**원인:** 다른 곳에서 동시 실행 중

**해결:**
```bash
# GCS에서 lock 확인 및 해제
gsutil ls gs://delabs-terraform-state-prod/jsj-game-f/**/.terraform.tfstate.lock.info

# 안전하다면 수동 삭제
gsutil rm gs://delabs-terraform-state-prod/jsj-game-f/[layer]/.terraform.tfstate.lock.info
```

---

### 문제 3: 승인 화면이 안 나타남

**증상:** Apply 실행했는데 승인 단계가 스킵됨

**원인:** `ACTION: plan` 선택

**해결:** `ACTION: apply`로 변경

---

### 문제 4: Terragrunt 명령어 실패

**증상:**
```
terragrunt: command not found
```

**원인:** Jenkins 컨테이너에 Terragrunt 미설치

**해결:**
```bash
# Jenkins 컨테이너 확인
docker exec jsj-jenkins-server terragrunt --version

# 없으면 재빌드
docker-compose -f jsj_jenkins.yaml down
docker-compose -f jsj_jenkins.yaml up -d --build
```

---

## GCP Credentials 설정

### 필수 설정

Terragrunt가 GCP에 접근하려면 Service Account 인증 정보가 필요합니다.

### 방법 1: Service Account Key 파일 (권장)

**1. GCP에서 Service Account 생성**

```bash
# GCP Console 또는 gcloud
gcloud iam service-accounts create jenkins-terraform \
    --display-name="Jenkins Terraform Automation"

# 권한 부여 (예시)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:jenkins-terraform@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor"

# Key 파일 생성
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account=jenkins-terraform@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

**2. Jenkins에 Credential 추가**

1. Jenkins → **Manage Jenkins** → **Credentials**
2. **(global)** → **Add Credentials**
3. 설정:
   ```
   Kind: Secret file
   File: jenkins-sa-key.json 업로드
   ID: gcp-service-account
   Description: GCP Service Account for Terraform
   ```

**3. Jenkinsfile 수정**

```groovy
environment {
    GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-service-account')
}
```

### 방법 2: Google Cloud Plugin (선택)

**1. Plugin 설치**
- Jenkins → Plugins → Available plugins
- 검색: `Google OAuth Credentials`
- Install

**2. Credential 추가**
- Manage Jenkins → Credentials
- Kind: Google Service Account from metadata
- 설정 완료

---

## 실행 명령어 참고

Pipeline에서 실제 실행되는 Terragrunt 명령어:

### Init

```bash
# 전체 스택
cd terraform_gcp_infra/environments/LIVE/jsj-game-f
terragrunt run-all init --terragrunt-non-interactive

# 개별 레이어
cd terraform_gcp_infra/environments/LIVE/jsj-game-f/10-network
terragrunt init --terragrunt-non-interactive
```

### Plan

```bash
# 전체 스택
terragrunt run-all plan --terragrunt-non-interactive -out=tfplan

# 개별 레이어
terragrunt plan --terragrunt-non-interactive -out=tfplan
```

### Apply

```bash
# 전체 스택 (의존성 순서 자동)
terragrunt run-all apply --terragrunt-non-interactive tfplan

# 개별 레이어
terragrunt apply --terragrunt-non-interactive tfplan
```

### Destroy

```bash
# 전체 스택 (역순으로 삭제)
terragrunt run-all destroy --terragrunt-non-interactive -auto-approve

# 개별 레이어
terragrunt destroy --terragrunt-non-interactive -auto-approve
```

---

## 모범 사례

### ✅ DO (권장)

1. **항상 Plan 먼저 실행**
   ```
   plan → 결과 확인 → apply
   ```

2. **개별 레이어 수정**
   - 변경이 필요한 레이어만 선택
   - 영향 범위 최소화

3. **승인 전 철저히 확인**
   - Plan 출력 전체 읽기
   - 예상치 못한 변경 확인
   - 삭제되는 리소스 확인

4. **테스트 환경 먼저**
   - QA 환경에서 먼저 테스트
   - 문제 없으면 LIVE 배포

5. **커밋 메시지 명확히**
   ```bash
   git commit -m "feat(network): add new subnet for web servers"
   ```

### ❌ DON'T (금지)

1. **Plan 없이 Apply 하지 마세요**
   - 예상치 못한 변경 위험

2. **전체 스택 Destroy 금지**
   - 특별한 경우 아니면 사용 금지
   - 모든 인프라가 삭제됨

3. **승인 없이 넘어가지 마세요**
   - 반드시 Plan 확인
   - 타임아웃 전에 승인

4. **동시에 여러 레이어 수정 금지**
   - 문제 발생 시 원인 파악 어려움
   - 한 번에 하나씩

---

## 추가 참고 자료

### 프로젝트 문서
- [Terragrunt 공식 문서](https://terragrunt.gruntwork.io/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

### 관련 문서
- [Jenkins 초기 설정](./JENKINS_SETUP.md)
- [GitHub 연동](./GITHUB_INTEGRATION.md)
- [프로젝트 README](./README.md)

---

**마지막 업데이트:** 2025-11-05
**Pipeline 버전:** 1.0.0
