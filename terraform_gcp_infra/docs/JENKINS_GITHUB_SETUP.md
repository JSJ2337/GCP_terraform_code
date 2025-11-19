# Jenkins GitHub Credential 설정 가이드

Jenkins에서 GitHub에 자동으로 푸시하고 PR을 생성하려면 GitHub Personal Access Token을 Jenkins Credential로 등록해야 합니다.

## 📋 목차

- [1단계: GitHub Personal Access Token 생성](#1단계-github-personal-access-token-생성)
- [2단계: Jenkins Credential 등록](#2단계-jenkins-credential-등록)
- [3단계: 설정 확인](#3단계-설정-확인)
- [트러블슈팅](#트러블슈팅)

---

## 1단계: GitHub Personal Access Token 생성

### 1.1 GitHub 설정 페이지 이동

1. GitHub에 로그인
2. 오른쪽 상단 프로필 아이콘 클릭 → **Settings**
3. 왼쪽 메뉴에서 **Developer settings** 클릭 (맨 아래)
4. **Personal access tokens** → **Tokens (classic)** 클릭

### 1.2 새 토큰 생성

1. **Generate new token** → **Generate new token (classic)** 클릭
2. 토큰 설정:

   | 항목 | 설정값 |
   |------|--------|
   | **Note** | `Jenkins Project Creation` (토큰 용도 설명) |
   | **Expiration** | `No expiration` 또는 `90 days` (권장: 90 days) |
   | **Select scopes** | 아래 권한 선택 |

3. **필수 권한 (Scopes) 선택:**

   ```
   ✅ repo (전체 선택)
      ✅ repo:status
      ✅ repo_deployment
      ✅ public_repo
      ✅ repo:invite
      ✅ security_events

   ✅ workflow (GitHub Actions workflow 파일 수정 권한)
   ```

   > **참고**: `repo` 권한은 private repository 접근을 포함합니다.

4. **Generate token** 버튼 클릭

### 1.3 토큰 복사 및 저장

```
⚠️  중요: 토큰은 생성 직후 한 번만 표시됩니다!
```

1. 생성된 토큰 복사 (예: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
2. 안전한 곳에 임시 저장 (메모장 등)

**토큰 형식:**
```
ghp_1234567890abcdefghijklmnopqrstuvwxyzABCD
```

---

## 2단계: Jenkins Credential 등록

### 2.1 Jenkins Credential 관리 페이지 이동

1. Jenkins 대시보드 접속
2. **Jenkins 관리** (Manage Jenkins) 클릭
3. **Credentials** 클릭
4. **(global)** 도메인 클릭
5. 왼쪽 메뉴에서 **Add Credentials** 클릭

### 2.2 Credential 정보 입력

| 필드 | 입력값 | 설명 |
|------|--------|------|
| **Kind** | `Secret text` | 드롭다운에서 선택 |
| **Scope** | `Global (Jenkins, nodes, items, all child items, etc)` | 기본값 유지 |
| **Secret** | `ghp_xxxx...` | 1단계에서 복사한 GitHub Token 붙여넣기 |
| **ID** | `github-token` | ⚠️  **반드시 이 값 사용!** (Jenkinsfile에서 참조) |
| **Description** | `GitHub Personal Access Token for project creation` | 설명 (선택사항) |

### 2.3 저장

1. **OK** 또는 **Create** 버튼 클릭
2. Credential 목록에서 `github-token` 확인

---

## 3단계: 설정 확인

### 3.1 Jenkins Job 실행

1. `create-terraform-project` Job으로 이동
2. **Build with Parameters** 클릭
3. 테스트 파라미터 입력:
   ```
   PROJECT_ID: jsj-test-proj
   PROJECT_NAME: test-proj
   ORGANIZATION: jsj
   REGION_PRIMARY: asia-northeast3
   REGION_BACKUP: asia-northeast1
   CREATE_PR: ✅
   ```
4. **Build** 클릭

### 3.2 빌드 로그 확인

성공 시 다음 메시지들이 표시됩니다:

```
✅ 브랜치 푸시 완료: feature/create-project-jsj-test-proj
✅ Pull Request 생성 완료!
```

### 3.3 GitHub 확인

1. GitHub Repository로 이동
2. **Pull requests** 탭에서 새로운 PR 확인:
   ```
   [Infra] jsj-test-proj 프로젝트 생성
   ```
3. **Branches** 탭에서 새 브랜치 확인:
   ```
   feature/create-project-jsj-test-proj
   ```

---

## 트러블슈팅

### 문제 1: "403 Forbidden" 에러

**에러 메시지:**
```
remote: Permission to JSJ2337/JSJ_engineering_Diary.git denied
fatal: unable to access 'https://github.com/...': The requested URL returned error: 403
```

**원인:**
- GitHub Token의 권한이 부족
- Token이 만료됨
- Credential ID가 잘못됨

**해결:**
1. GitHub에서 토큰 권한 확인 (`repo` 권한 필요)
2. 토큰 만료 확인 (Settings → Developer settings → Personal access tokens)
3. Jenkins Credential ID가 정확히 `github-token`인지 확인

---

### 문제 2: "could not read Username" 에러

**에러 메시지:**
```
fatal: could not read Username for 'https://github.com': No such device or address
```

**원인:**
- Credential이 제대로 전달되지 않음
- `withCredentials` 블록 문제

**해결:**
1. Jenkinsfile의 `credentialsId: 'github-token'` 확인
2. Jenkins Credential에 `github-token` ID로 등록되었는지 확인
3. Jenkins Job 재실행

---

### 문제 3: gh CLI 인증 실패

**에러 메시지:**
```
gh: To use GitHub CLI in a GitHub Actions workflow, set the GH_TOKEN environment variable
```

**원인:**
- gh CLI가 GitHub Token을 받지 못함

**해결:**
1. Jenkinsfile에서 `export GH_TOKEN=${GITHUB_TOKEN}` 라인 확인
2. `withCredentials` 블록이 올바르게 적용되었는지 확인

---

### 문제 4: Token이 로그에 노출됨

**증상:**
- Jenkins 로그에 `ghp_xxx...` 형태의 토큰이 평문으로 보임

**해결:**
- Jenkins는 자동으로 Credential 값을 `****`로 마스킹합니다
- 만약 노출된다면 스크립트에서 `echo` 명령으로 토큰을 출력하지 않도록 주의

**예:**
```groovy
// ❌ 나쁜 예
sh "echo ${GITHUB_TOKEN}"  // 토큰 노출!

// ✅ 좋은 예
withCredentials([...]) {
    sh """
        git push ...  // 토큰은 자동 마스킹됨
    """
}
```

---

### 문제 5: Repository URL이 잘못됨

**에러 메시지:**
```
fatal: repository 'https://github.com/.../' not found
```

**원인:**
- Jenkinsfile에 하드코딩된 Repository URL이 다름

**해결:**

Jenkinsfile의 다음 라인 확인:
```groovy
git remote set-url origin https://${GITHUB_TOKEN}@github.com/JSJ2337/JSJ_engineering_Diary.git
```

여러분의 Repository로 수정:
```groovy
git remote set-url origin https://${GITHUB_TOKEN}@github.com/<YOUR_ORG>/<YOUR_REPO>.git
```

---

## 보안 권장사항

### 1. Token 만료 기간 설정
- ✅ **권장**: 90일 만료로 설정
- ❌ **비권장**: No expiration (보안 위험)

### 2. Token 권한 최소화
- 필요한 권한만 선택 (`repo`, `workflow`)
- 불필요한 권한은 체크 해제

### 3. Token 정기 갱신
- 만료 전 새 토큰 생성
- Jenkins Credential 업데이트
- 이전 토큰 삭제

### 4. Token 노출 시 대응
1. 즉시 GitHub에서 해당 토큰 삭제
2. 새 토큰 생성
3. Jenkins Credential 업데이트
4. Git 히스토리에 토큰이 남았다면 Repository 보안팀 문의

---

## 추가 정보

### Fine-grained Personal Access Token (Beta)

GitHub의 새로운 토큰 유형으로, Repository별로 세밀한 권한 제어 가능:

**설정 방법:**
1. **Personal access tokens** → **Fine-grained tokens** 클릭
2. **Generate new token** 클릭
3. Repository 선택: `JSJ2337/JSJ_engineering_Diary`
4. 권한 설정:
   - **Contents**: Read and write
   - **Pull requests**: Read and write
   - **Workflows**: Read and write

**장점:**
- Repository별 권한 분리
- 더 세밀한 권한 제어
- 보안성 향상

**단점:**
- 아직 Beta 단계
- 일부 Jenkins 플러그인과 호환성 문제 가능

---

## 참고 문서

- [GitHub: Creating a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Jenkins: Credentials Plugin](https://plugins.jenkins.io/credentials/)
- [GitHub CLI: Authentication](https://cli.github.com/manual/gh_auth_login)
