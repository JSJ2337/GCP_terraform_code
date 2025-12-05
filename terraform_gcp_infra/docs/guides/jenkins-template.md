# Jenkins 템플릿

이 디렉터리는 새로운 환경을 위한 Jenkinsfile 템플릿을 포함합니다.

## 📁 구조

```
.jenkins/
├── Jenkinsfile.template  # Terragrunt CI/CD Pipeline 템플릿
└── README.md             # 이 문서
```

---

## 🚀 사용 방법

### 1. 새 프로젝트 생성 시

```bash
# 1. 템플릿 복사
cp -r proj-default-templet environments/LIVE/your-new-project

# 2. Jenkinsfile 복사
cp .jenkins/Jenkinsfile.template environments/LIVE/your-new-project/Jenkinsfile

# 3. 커스터마이징 (선택)
# - TARGET_LAYER choices (레이어 추가/제거)
# - submitter 변경 (승인자 제한)
# - timeout 시간 조정
```

### 2. Jenkins Job 생성

**Jenkins 대시보드**:
1. **New Item** 클릭
2. Job 이름: `your-new-project-pipeline`
3. Type: **Pipeline** 선택
4. **OK** 클릭

**Pipeline 설정**:
1. **Pipeline** 섹션으로 스크롤
2. Definition: **Pipeline script from SCM** 선택
3. SCM: **Git** 선택
4. Repository URL: 입력
5. Branch Specifier: `*/433_code` (또는 사용 중인 브랜치)
6. **Script Path**: `environments/LIVE/your-new-project/Jenkinsfile`
7. **Save** 클릭

---

## 🎯 Jenkinsfile.template 특징

### 기본 기능
- ✅ Plan/Apply/Destroy 파라미터 선택
- ✅ 전체 스택 또는 개별 레이어 실행
- ✅ 수동 승인 단계 (30분 타임아웃)
- ✅ Admin 사용자만 승인 가능
- ✅ 자동 cleanup (tfplan, lock 파일)

### 환경 변수
- `TF_IN_AUTOMATION = 'true'`: Terraform 자동화 모드
- `TF_INPUT = 'false'`: 사용자 입력 비활성화
- `TG_WORKING_DIR = '.'`: Terragrunt 작업 디렉터리 (환경 루트)

### 파라미터
- **ACTION**: plan, apply, destroy 선택
- **TARGET_LAYER**: all 또는 개별 레이어 (00-project ~ 70-loadbalancer)

---

## 🔧 커스터마이징 예시

### 승인자 변경

```groovy
// admin만 승인 가능 (기본)
submitter: 'admin'

// 여러 사용자 승인 가능
submitter: 'admin,devops,manager'

// 모든 사용자 승인 가능 (비권장)
// submitter 줄 제거
```

### 타임아웃 조정

```groovy
// 30분 (기본)
timeout(time: 30, unit: 'MINUTES')

// 1시간
timeout(time: 60, unit: 'MINUTES')

// 무제한 (비권장)
// timeout 블록 제거
```

### 레이어 추가/제거

```groovy
choices: [
    'all',
    '00-project',
    '10-network',
    // ... 기존 레이어들 ...
    '80-cdn',        // 새 레이어 추가
    '90-monitoring'  // 새 레이어 추가
]
```

---

## 📋 환경별 Jenkinsfile 관리

### 왜 환경별로 분리?

1. **독립성**: 각 프로젝트 완전히 독립적
2. **유연성**: 프로젝트별 특수 요구사항 대응 가능
3. **명확성**: 어떤 프로젝트인지 즉시 파악
4. **확장성**: 프로젝트 추가 시 템플릿만 복사

### 디렉터리 구조

```
environments/LIVE/
├── jsj-game-g/
│   ├── Jenkinsfile           # jsj-game-g 전용
│   ├── 00-project/
│   └── ...
├── jsj-game-h/
│   ├── Jenkinsfile           # jsj-game-h 전용
│   └── ...
└── your-new-project/
    ├── Jenkinsfile           # your-new-project 전용
    └── ...
```

---

## 🔗 관련 문서

- [Jenkins 초기 설정](../../jenkins_docker/JENKINS_SETUP.md)
- [GitHub 연동](../../jenkins_docker/GITHUB_INTEGRATION.md)
- [Terragrunt CI/CD Pipeline](../../jenkins_docker/TERRAGRUNT_PIPELINE.md)
- [프로젝트 README](../00_README.md)

---

## ✅ Jenkins Service Account 권한 점검
- `delabs-system-mgmt` 프로젝트: `roles/storage.admin` (State 버킷 접근)
- 조직/폴더: `roles/resourcemanager.projectCreator`, `roles/editor`
- Billing Account `01076D-327AD5-FC8922`: `roles/billing.user`
- Cloud Billing API와 Service Usage API가 `delabs-system-mgmt`에서 활성화되어 있는지 확인하세요.

---

## 📝 최근 변경사항

### 2025-11-12
- 단일 레이어 실행 시 경로 문제 해결: 모든 terragrunt 명령에 `--working-dir` 플래그 사용으로 일관성 확보

---

**마지막 업데이트**: 2025-11-12
