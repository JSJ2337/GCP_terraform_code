# Jenkins CI/CD 가이드

Jenkins를 통한 Terraform 인프라 자동화 가이드입니다.

## 개요

이 저장소는 Jenkins를 통한 자동화된 Terragrunt 배포를 지원합니다.

```
GitHub Push → Jenkins Webhook → Pipeline 실행 → Terraform Apply
```

## Jenkins 설정

### Docker 기반 Jenkins (권장)

Jenkins Docker 설정은 별도 저장소에서 관리됩니다:
- Jenkins LTS + Terraform + Terragrunt + Git 사전 설치
- GitHub Webhook 자동 빌드 지원
- ngrok을 통한 외부 접속 (선택)

**상세 가이드**:
- Jenkins 초기 설정
- GitHub 연동
- Terragrunt CI/CD Pipeline

### 필수 플러그인
- Git
- Pipeline
- Credentials Binding
- GitHub Integration

## Jenkinsfile 구조

### 위치
각 환경 디렉터리에 Jenkinsfile 배치:
```
environments/LIVE/jsj-game-k/Jenkinsfile
environments/LIVE/jsj-game-l/Jenkinsfile
```

### 템플릿
새 프로젝트 생성 시 복사:
```bash
cp .jenkins/Jenkinsfile.template environments/LIVE/my-project/Jenkinsfile
```

### 주요 기능
- ✅ Plan/Apply/Destroy 파라미터 선택
- ✅ 전체 스택 또는 개별 레이어 실행
- ✅ **수동 승인 단계** (Apply/Destroy 전 필수)
- ✅ 30분 승인 타임아웃
- ✅ Admin 사용자만 승인 가능

### Pipeline 단계
```
1. Checkout
   ↓
2. Environment Check
   ↓
3. Terragrunt Init
   ↓
4. Terragrunt Plan
   ↓
5. Review Plan (apply/destroy 시)
   ↓
6. 🛑 Manual Approval 🛑 (30분 타임아웃)
   ↓
7. Terragrunt Apply/Destroy
```

## GCP 인증 설정

### Service Account 생성

Bootstrap에서 자동 생성:
```bash
cd bootstrap
terraform apply  # jenkins-terraform-admin SA 생성
```

**생성되는 리소스**:
- SA: `jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com`
- 조직 레벨 권한 (조직이 있는 경우)

### Key 파일 생성

```bash
gcloud iam service-accounts keys create jenkins-sa-key.json \
    --iam-account=jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com \
    --project=jsj-system-mgmt
```

### Jenkins Credential 등록

```
Jenkins → Manage Jenkins → Credentials → Add Credentials
- Kind: Secret file
- File: jenkins-sa-key.json 업로드
- ID: gcp-jenkins-service-account  ⚠️ 정확히 이 ID로!
- Description: GCP Service Account for Jenkins Terraform
```

### 필수 권한

**State 버킷 (jsj-system-mgmt)**:
```bash
gcloud projects add-iam-policy-binding jsj-system-mgmt \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/storage.admin"
```

**Billing Account**:
```bash
gcloud beta billing accounts add-iam-policy-binding 01076D-327AD5-FC8922 \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"
```

**워크로드 프로젝트** (각각):
```bash
gcloud projects add-iam-policy-binding jsj-game-k \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/editor"
```

## Jenkinsfile 설정

### 환경 변수
```groovy
environment {
    GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-jenkins-service-account')
    TG_WORKING_DIR = 'terraform_gcp_infra/environments/LIVE/jsj-game-k'
    TG_NON_INTERACTIVE = 'true'
}
```

**⚠️ 중요**:
- Credential ID는 반드시 `gcp-jenkins-service-account`
- `TG_WORKING_DIR`은 workspace root 기준 절대 경로
- 템플릿 복사 시 프로젝트 이름 변경 필수

### 파라미터
```groovy
parameters {
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'])
    choice(name: 'SCOPE', choices: ['all', 'single'])
    string(name: 'LAYER', defaultValue: '00-project')
}
```

## Jenkins Job 생성

### Pipeline Job
```
New Item → Pipeline
- Name: terraform-jsj-game-k
- Pipeline script from SCM
- SCM: Git
- Repository URL: <your-repo>
- Branch: 433_code
- Script Path: environments/LIVE/jsj-game-k/Jenkinsfile
```

### GitHub Webhook (선택)
```
GitHub Repository → Settings → Webhooks → Add webhook
- Payload URL: http://jenkins.example.com/github-webhook/
- Content type: application/json
- Events: Push, Pull request
```

## 사용법

### 수동 실행
```
Jenkins Dashboard → terraform-jsj-game-k → Build with Parameters
- ACTION: apply
- SCOPE: all
- Build 클릭
```

### 승인 프로세스
1. Plan 단계 완료 후 대기
2. "Review Plan" 로그 확인
3. Admin 사용자가 "Proceed" 클릭
4. Apply 실행

### 로그 확인
```
Build → Console Output
```

## 베스트 프랙티스

### 1. 항상 Plan 먼저
```
1. ACTION=plan 실행
2. 결과 검토
3. ACTION=apply 실행
```

### 2. 단일 레이어 테스트
```
- SCOPE: single
- LAYER: 00-project
```

### 3. 백업 확인
```bash
# State 버킷 백업 확인
gsutil ls gs://jsj-terraform-state-prod/backup/
```

### 4. 권한 최소화
- 프로젝트별 필요한 권한만 부여
- 정기적으로 SA Key 교체
- Key 유출 시 즉시 폐기

## 트러블슈팅

### "Permission denied"
→ [GCP 인증 설정](#gcp-인증-설정) 확인

### "Credential not found"
→ Jenkins Credential ID가 `gcp-jenkins-service-account`인지 확인

### "Working directory not found"
→ `TG_WORKING_DIR` 경로 확인 (workspace root 기준)

### Timeout
→ `timeout(time: 60, unit: 'MINUTES')` 조정

## 참고

상세한 내용은 루트 README의 Jenkins CI/CD 섹션을 참조하세요.

---

**관련 문서**:
- [Terragrunt 사용법](./terragrunt-usage.md)
- [새 프로젝트 추가](./adding-new-project.md)
- [트러블슈팅](../troubleshooting/common-errors.md)
