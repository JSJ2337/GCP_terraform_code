# Jenkins CI/CD 가이드

Jenkins를 통한 Phase 기반 Terraform 인프라 자동화 가이드입니다.

## 개요

이 저장소는 Jenkins를 통한 자동화된 Phase 기반 Terragrunt 배포를 지원합니다.

```text
GitHub Push → Jenkins Webhook → Phase-Based Pipeline → Terraform Apply
```

**핵심 특징:**

- ✅ **Phase 기반 배포**: 8개 Phase로 의존성 자동 해결
- ✅ **전체 승인 한 번**: TARGET_LAYER=all 시 모든 Phase를 한 번에 승인
- ✅ **Stale Plan 방지**: Apply 직전 Re-plan 자동 실행
- ✅ **Mock Outputs 해결**: Phase 순차 실행으로 순환 참조 문제 근본 해결

## Phase 기반 배포 시스템

### Phase 정의

Jenkins는 8개의 Phase로 인프라를 순차 배포하여 의존성을 자동 해결합니다:

| Phase | 레이어 | 설명 | 의존성 | Optional |
|-------|--------|------|--------|----------|
| **Phase 1** | `00-project` | GCP 프로젝트 생성, API 활성화 | Bootstrap | ❌ |
| **Phase 2** | `10-network` | VPC 네트워킹 구성 | 00-project | ❌ |
| **Phase 3** | `12-dns` | Cloud DNS (Public/Private) | 10-network | ❌ |
| **Phase 4** | `20-storage`<br>`30-security` | GCS 버킷, IAM/SA | 10-network | ❌ |
| **Phase 5** | `40-observability` | Logging/Monitoring/Slack | 20-storage, 30-security | ✅ |
| **Phase 6** | `50-workloads` | VM 인스턴스 배포 | 10-network, 30-security | ❌ |
| **Phase 7** | `60-database`<br>`65-cache` | Cloud SQL, Redis 캐시 | 10-network | ❌ |
| **Phase 8** | `70-loadbalancers/gs` | Load Balancer (Game Server) | 50-workloads | ❌ |

### 배포 흐름

```text
Step 1: 모든 Phase Plan 실행 (순차)
   ↓
Step 2: 전체 승인 (한 번만, 30분 타임아웃)
   ↓
Step 3: 각 Phase별 Re-plan → Apply (순차)
```

### TARGET_LAYER 파라미터

```groovy
parameters {
    choice(name: 'TARGET_LAYER',
           choices: ['all', '00-project', '10-network', '20-storage', ...],
           description: 'Target layer to deploy')
    choice(name: 'ACTION',
           choices: ['plan', 'apply', 'destroy'],
           description: 'Action to perform')
    booleanParam(name: 'ENABLE_OBSERVABILITY',
                 defaultValue: true,
                 description: 'Include 40-observability layer')
}
```

**동작 방식:**

- **all**: 모든 Phase를 순차적으로 실행
  - Plan → 전체 승인 → 각 Phase Re-plan + Apply
  - Phase 4 (observability)는 `ENABLE_OBSERVABILITY` 파라미터로 제어

- **특정 레이어** (예: `10-network`):
  - 해당 레이어만 Plan → 승인 → Apply

### Re-plan 메커니즘

Apply 직전에 자동으로 Re-plan을 실행하여 stale plan 문제를 방지합니다:

**문제 상황:**

```text
10:00 - Phase 1 Plan 생성 (tfplan-phase1)
10:05 - Phase 2 Plan 생성 (tfplan-phase2)
10:30 - 승인
10:31 - Phase 1 Apply (30분 전 plan 사용, 최신 상태 아님)
10:32 - Phase 2 Apply (Phase 1 변경사항 미반영)
```

**해결 방법:**

```groovy
stage("Phase ${phase.id} - Replan & Apply") {
    steps {
        echo "📋 Re-planning ${phase.label} with latest state..."
        script {
            runPhasePlan(phase, phaseDirs)  // Fresh plan 생성
        }

        echo "🚀 Applying ${phase.label}..."
        script {
            runPhaseApply(phase, phaseDirs)  // 최신 plan 즉시 apply
        }
    }
}
```

**효과:**

- 각 Phase가 항상 최신 State 기반으로 apply
- 의존성 변경사항 즉시 반영
- Stale plan 문제 완전 해결

### Optional Phase 처리

Phase 4 (40-observability)는 선택적으로 배포:

```groovy
if (phase.optional && phase.id == 'phase4' &&
    !params.ENABLE_OBSERVABILITY && params.ACTION != 'destroy') {
    echo "⏭️  Skipping ${phase.label} (disabled by parameter)"
    return
}
```

**주의사항:**

- Apply/Plan 시: `ENABLE_OBSERVABILITY=false`면 skip
- Destroy 시: 항상 포함 (orphan 방지)

### Mock Outputs 문제 해결

**문제:**

```text
기존 방식: 모든 레이어를 동시에 plan
→ 10-network 미적용 상태에서 50-workloads가 mock 서브넷 참조
→ apply 시 실제 서브넷을 찾을 수 없어 404 에러
```

**해결:**

```text
Phase 기반: Phase 순서대로 순차 실행
→ Phase 2 (10-network) 먼저 apply
→ Phase 5 (50-workloads) 실행 시 실제 서브넷 참조 가능
```

## Jenkins 설정

### Docker 기반 Jenkins (권장)

Jenkins Docker 설정:

- Jenkins LTS + Terraform + Terragrunt + Git 사전 설치
- GitHub Webhook 자동 빌드 지원
- ngrok을 통한 외부 접속 (선택)

**상세 가이드**: [JENKINS_GITHUB_SETUP.md](../JENKINS_GITHUB_SETUP.md)

### 필수 플러그인

- Git
- Pipeline
- Credentials Binding
- GitHub Integration
- Pipeline: Stage View (권장)

## Jenkinsfile 구조

### 위치

각 환경 디렉터리에 Jenkinsfile 배치:

```text
environments/LIVE/jsj-game-n/Jenkinsfile
proj-default-templet/Jenkinsfile (템플릿)
```

### 템플릿

새 프로젝트 생성 시 복사:

```bash
cp proj-default-templet/Jenkinsfile environments/LIVE/my-project/Jenkinsfile

# TG_WORKING_DIR 수정 필수!
vim environments/LIVE/my-project/Jenkinsfile
# TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/my-project'
```

### 주요 기능

- ✅ Plan/Apply/Destroy 파라미터 선택
- ✅ 전체 스택(all) 또는 개별 레이어 실행
- ✅ **Phase 기반 순차 배포** (8개 Phase)
- ✅ **전체 승인 한 번** (TARGET_LAYER=all 시)
- ✅ **Apply 직전 Re-plan** (stale plan 방지)
- ✅ 30분 승인 타임아웃
- ✅ Admin 사용자만 승인 가능

### Pipeline 단계 (TARGET_LAYER=all)

```text
1. Checkout
   ↓
2. Environment Check
   ↓
3. Terragrunt Init
   ↓
4. Plan All Phases (순차)
   ├─ Phase 1 Plan
   ├─ Phase 2 Plan
   ├─ Phase 3 Plan
   ├─ ... (Phase 8까지)
   ↓
5. Review Plan Summary
   ↓
6. 🛑 Manual Approval (전체 한 번) 🛑
   ↓
7. Execute All Phases (순차)
   ├─ Phase 1: Re-plan → Apply
   ├─ Phase 2: Re-plan → Apply
   ├─ ... (Phase 8까지)
```

### Jenkinsfile 예제 (Phase 기반)

```groovy
@Library('shared-library') _

// Phase 정의
def PHASES = [
    [id: 'phase1', label: 'Phase 1: Project Setup', dirs: ['00-project'], optional: false],
    [id: 'phase2', label: 'Phase 2: Network', dirs: ['10-network'], optional: false],
    [id: 'phase3', label: 'Phase 3: Storage & Security', dirs: ['20-storage', '30-security'], optional: false],
    [id: 'phase4', label: 'Phase 4: Observability', dirs: ['40-observability'], optional: true],
    [id: 'phase5', label: 'Phase 5: Workloads', dirs: ['50-workloads'], optional: false],
    [id: 'phase6', label: 'Phase 6: Database & Cache', dirs: ['60-database', '65-cache'], optional: false],
    [id: 'phase7', label: 'Phase 7: Load Balancers', dirs: ['70-loadbalancers'], optional: false],
    [id: 'phase8', label: 'Phase 8: DNS', dirs: ['12-dns'], optional: false]
]

pipeline {
    agent any

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-jenkins-service-account')
        TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/jsj-game-n'
        TG_NON_INTERACTIVE = 'true'
    }

    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'])
        choice(name: 'TARGET_LAYER', choices: ['all', '00-project', '10-network', ...])
        booleanParam(name: 'ENABLE_OBSERVABILITY', defaultValue: true)
    }

    stages {
        stage('Plan All Phases') {
            when {
                expression { params.TARGET_LAYER == 'all' }
            }
            steps {
                script {
                    PHASES.each { phase ->
                        stage("${phase.label} - Plan") {
                            runPhasePlan(phase, phase.dirs)
                        }
                    }
                }
            }
        }

        stage('Approve All Phases') {
            when {
                expression { params.TARGET_LAYER == 'all' && params.ACTION in ['apply', 'destroy'] }
            }
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: "Approve ${params.ACTION} for all phases?",
                          submitter: 'admin'
                }
            }
        }

        stage('Execute All Phases') {
            when {
                expression { params.TARGET_LAYER == 'all' }
            }
            steps {
                script {
                    PHASES.each { phase ->
                        // Optional phase 처리
                        if (phase.optional && phase.id == 'phase4' &&
                            !params.ENABLE_OBSERVABILITY && params.ACTION != 'destroy') {
                            echo "⏭️  Skipping ${phase.label}"
                            return
                        }

                        stage("${phase.label} - Replan & Apply") {
                            echo "📋 Re-planning ${phase.label}..."
                            runPhasePlan(phase, phase.dirs)

                            echo "🚀 Applying ${phase.label}..."
                            runPhaseApply(phase, phase.dirs)
                        }
                    }
                }
            }
        }
    }
}

def runPhasePlan(phase, dirs) {
    dirs.each { dir ->
        sh """
            cd ${TG_WORKING_DIR}
            terragrunt run --all --queue-include-dir ${dir} -- plan -out=tfplan-${phase.id}
        """
    }
}

def runPhaseApply(phase, dirs) {
    dirs.each { dir ->
        sh """
            cd ${TG_WORKING_DIR}
            terragrunt run --all --queue-include-dir ${dir} -- apply tfplan-${phase.id}
        """
    }
}
```

## GCP 인증 설정

### Service Account 생성

Bootstrap에서 자동 생성:

```bash
cd bootstrap
terraform apply  # jenkins-terraform-admin SA 생성
```

**생성되는 리소스:**

- SA: `jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com`
- 조직 레벨 권한 (조직이 있는 경우)

### Key 파일 생성

```bash
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account="${SA_EMAIL}" \
    --project=jsj-system-mgmt
```

### Jenkins Credential 등록

```text
Jenkins → Manage Jenkins → Credentials → Add Credentials
- 종류(Kind): Secret file
- 파일(File): jenkins-sa-key.json 업로드
- ID: gcp-jenkins-service-account  ⚠️ 정확히 이 ID로!
- 설명(Description): Jenkins Terraform용 GCP Service Account
```

### 필수 권한

**State 버킷 (jsj-system-mgmt)**:

```bash
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud projects add-iam-policy-binding jsj-system-mgmt \
    --member="${SA_MEMBER}" \
    --role="roles/storage.admin"
```

**Billing Account**:

```bash
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="${SA_MEMBER}" \
    --role="roles/billing.user"
```

**워크로드 프로젝트** (각각):

```bash
SA_EMAIL="jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"
SA_MEMBER="serviceAccount:${SA_EMAIL}"
gcloud projects add-iam-policy-binding jsj-game-n \
    --member="${SA_MEMBER}" \
    --role="roles/editor"
```

## Jenkinsfile 설정

### 환경 변수

```groovy
environment {
    GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-jenkins-service-account')
    TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/jsj-game-n'
    TG_NON_INTERACTIVE = 'true'

    // Terragrunt 0.93+ 호환
    TF_VERSION = '1.10+'
    TG_VERSION = '0.93+'
}
```

**⚠️ 중요**:

- Credential ID는 반드시 `gcp-jenkins-service-account`
- `TG_WORKING_DIR`은 workspace root 기준 **절대 경로**
- 템플릿 복사 시 프로젝트 이름 변경 필수
- Terragrunt 0.93+ 구문 사용

### 파라미터

```groovy
parameters {
    choice(
        name: 'ACTION',
        choices: ['plan', 'apply', 'destroy'],
        description: 'Terraform action to perform'
    )
    choice(
        name: 'TARGET_LAYER',
        choices: ['all', '00-project', '10-network', '20-storage', '30-security',
                  '40-observability', '50-workloads', '60-database', '65-cache',
                  '70-loadbalancers', '12-dns'],
        description: 'Target layer to deploy (all = all phases sequentially)'
    )
    booleanParam(
        name: 'ENABLE_OBSERVABILITY',
        defaultValue: true,
        description: 'Include 40-observability layer (only for TARGET_LAYER=all)'
    )
}
```

## Jenkins Job 생성

### Pipeline Job

```text
Jenkins → New Item → Pipeline

Configuration:
- Name: terraform-jsj-game-n
- Pipeline script from SCM
- SCM: Git
- Repository URL: <your-repo>
- Branch: main (또는 433_code)
- Script Path: terraform_gcp_infra/environments/LIVE/jsj-game-n/Jenkinsfile
```

### Build Triggers

**GitHub Webhook (권장)**:

```text
GitHub Repository → Settings → Webhooks → Add webhook
- Payload URL: http://jenkins.example.com/github-webhook/
- Content type: application/json
- Events: Push, Pull request
```

**Polling (대안)**:

```groovy
triggers {
    pollSCM('H/15 * * * *')  // 15분마다 체크
}
```

## 사용법

### Phase 기반 전체 배포

```text
Jenkins Dashboard → terraform-jsj-game-n → Build with Parameters

Parameters:
- ACTION: apply
- TARGET_LAYER: all
- ENABLE_OBSERVABILITY: true

→ Build 클릭
```

**실행 순서:**

1. 모든 Phase Plan (순차)
2. Plan 결과 검토
3. 전체 승인 (한 번)
4. 각 Phase Re-plan + Apply (순차)

### 단일 레이어 배포

```text
Parameters:
- ACTION: apply
- TARGET_LAYER: 10-network
- ENABLE_OBSERVABILITY: N/A (무시됨)

→ Build 클릭
```

**실행 순서:**

1. 10-network Plan
2. Plan 결과 검토
3. 승인
4. 10-network Apply

### 승인 프로세스

1. Plan 단계 완료 후 대기
2. "Review Plan" 로그 확인
3. Admin 사용자가 "Proceed" 클릭
4. Apply 실행

### 로그 확인

```text
Build → Console Output

주요 로그 라인:
- 📋 Planning Phase X...
- ✅ Phase X plan completed
- 🚀 Applying Phase X...
- ✅ Phase X apply completed
```

## 베스트 프랙티스

### 1. 항상 Plan 먼저

```text
1. ACTION=plan, TARGET_LAYER=all 실행
2. 결과 검토
3. ACTION=apply, TARGET_LAYER=all 실행
```

### 2. 개발 시 단일 레이어 테스트

```text
개발 중인 레이어만 빠르게 테스트:
- TARGET_LAYER: 50-workloads
- ACTION: plan
```

### 3. Observability 선택적 배포

```text
프로덕션:
- ENABLE_OBSERVABILITY: true

개발/테스트:
- ENABLE_OBSERVABILITY: false (비용 절감)
```

### 4. 백업 확인

```bash
# State 버킷 백업 확인
gsutil ls gs://jsj-terraform-state-prod/backup/

# 최신 백업 확인
gsutil ls -l gs://jsj-terraform-state-prod/backup/ | tail -5
```

### 5. 권한 최소화

- 프로젝트별 필요한 권한만 부여
- 정기적으로 SA Key 교체 (90일 권장)
- Key 유출 시 즉시 폐기

```bash
# Key 폐기
gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com
```

### 6. Phase별 배포 시간 예상

| Phase | 예상 시간 | 주요 작업 |
|-------|----------|----------|
| Phase 1 | 5-10분 | 프로젝트 생성, API 활성화 (120초 대기) |
| Phase 2 | 3-5분 | VPC, 서브넷, Firewall |
| Phase 3 | 2-3분 | GCS 버킷, IAM |
| Phase 4 | 2-3분 | Log Sink, Alert (Optional) |
| Phase 5 | 10-15분 | VM 인스턴스, 부팅 |
| Phase 6 | 15-20분 | Cloud SQL, Redis |
| Phase 7 | 5-10분 | Load Balancer |
| Phase 8 | 2-3분 | Cloud DNS |
| **전체** | **45-70분** | Phase 1-8 전체 |

## 트러블슈팅

### "Permission denied"

**원인**: GCP Service Account 권한 부족

**해결**:

```bash
# 권한 확인
gcloud projects get-iam-policy jsj-game-n \
    --flatten="bindings[].members" \
    --filter="bindings.members:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com"

# 권한 추가
gcloud projects add-iam-policy-binding jsj-game-n \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/editor"
```

### "Credential not found"

**원인**: Jenkins Credential ID 불일치

**해결**:

- Jenkins Credential ID가 정확히 `gcp-jenkins-service-account`인지 확인
- Jenkinsfile의 `credentials('gcp-jenkins-service-account')` 부분 확인

### "Working directory not found"

**원인**: `TG_WORKING_DIR` 경로 오류

**해결**:

```groovy
// ❌ 잘못된 경로 (상대 경로)
TG_WORKING_DIR = './environments/LIVE/jsj-game-n'

// ✅ 올바른 경로 (workspace root 기준 절대 경로)
TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/jsj-game-n'
```

### Timeout

**원인**: Phase별 실행 시간 초과

**해결**:

```groovy
// Jenkinsfile에서 타임아웃 조정
timeout(time: 60, unit: 'MINUTES') {
    // ...
}

// 또는 Phase별 타임아웃
stage('Phase 6 - Database & Cache') {
    timeout(time: 30, unit: 'MINUTES') {  // Cloud SQL은 시간이 오래 걸림
        // ...
    }
}
```

### Mock outputs 404 에러

**원인**: 10-network 미적용 상태에서 50-workloads가 mock 서브넷 참조

**해결**: Phase 기반 배포 사용

```text
TARGET_LAYER=all로 배포하면 자동 해결
Phase 순서대로 apply하므로 10-network가 먼저 적용됨
```

### Stale plan 에러

**원인**: Plan 생성 후 다른 Phase가 State를 변경

**해결**: Phase 기반 배포는 Re-plan 자동 실행 (수동 조치 불필요)

```text
Jenkins Phase 기반 배포:
1. Plan → 2. 승인 → 3. Re-plan → 4. Apply (자동)

수동 배포 시:
terragrunt plan -out=tfplan && terragrunt apply tfplan
```

### API Propagation 타임아웃

**원인**: GCP API 활성화 후 즉시 사용 불가

**해결**: Jenkinsfile에 대기 시간 포함됨

```groovy
// Phase 1 완료 후 자동 대기 (120초)
sh "echo 'Waiting for API propagation...'"
sh "sleep 120"
```

## 참고 자료

### 관련 문서

- [Terragrunt 사용법](./terragrunt-usage.md) - Terragrunt 0.93+ 구문
- [새 프로젝트 추가](./adding-new-project.md) - Phase 기반 배포 가이드
- [트러블슈팅](../troubleshooting/common-errors.md) - 일반적인 오류 해결
- [Phase 기반 배포 상세](../README.md#phase-기반-배포-시스템) - Phase 설계 원칙

### 외부 자료

- [Terragrunt 0.93+ 문서](https://terragrunt.gruntwork.io/docs/)
- [Jenkins Pipeline 문서](https://www.jenkins.io/doc/book/pipeline/)
- [GCP Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)

---

**Last Updated: 2025-11-21**
**Version: Phase-Based v2.0**
