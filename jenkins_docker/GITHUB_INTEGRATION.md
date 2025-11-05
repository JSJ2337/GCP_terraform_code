# GitHub 연동 가이드

Jenkins와 GitHub을 연동하여 자동 빌드, Webhook, Pipeline을 설정하는 방법을 설명합니다.

## 목차

- [사전 준비](#사전-준비)
- [1단계: GitHub Personal Access Token 생성](#1단계-github-personal-access-token-생성)
- [2단계: Jenkins Credentials 추가](#2단계-jenkins-credentials-추가)
- [3단계: GitHub Server 설정](#3단계-github-server-설정)
- [4단계: Pipeline Job 생성](#4단계-pipeline-job-생성)
- [5단계: GitHub Webhook 설정](#5단계-github-webhook-설정)
- [테스트 및 확인](#테스트-및-확인)
- [문제 해결](#문제-해결)

---

## 사전 준비

### 필요한 것

- ✅ Jenkins 초기 설정 완료 ([JENKINS_SETUP.md](./JENKINS_SETUP.md) 참조)
- ✅ GitHub 계정
- ✅ GitHub 리포지토리 (Public 또는 Private)
- ✅ ngrok 실행 중 (Webhook 사용 시)

### GitHub Plugin 확인

다음 플러그인이 설치되어 있어야 합니다:

```
✅ Git plugin
✅ GitHub plugin
✅ GitHub Integration Plugin
✅ GitHub API Plugin
✅ Credentials Plugin
✅ Credentials Binding Plugin
```

**확인 방법:** Manage Jenkins → Plugins → Installed plugins

---

## 1단계: GitHub Personal Access Token 생성

GitHub API 접근을 위한 토큰을 발급받습니다.

### 1-1. GitHub 접속

1. https://github.com 접속
2. 우측 상단 **프로필 아이콘** 클릭
3. **Settings** 선택

### 1-2. Developer settings 이동

1. 왼쪽 메뉴 맨 아래 **Developer settings** 클릭
2. **Personal access tokens** → **Tokens (classic)** 클릭

### 1-3. 새 토큰 생성

1. **Generate new token** → **Generate new token (classic)** 선택

2. **토큰 설정:**
   ```
   Note: Jenkins Token
   (토큰 용도 설명 - 나중에 구분하기 위함)

   Expiration: 원하는 기간 선택
   - 30 days
   - 60 days
   - 90 days
   - Custom
   - No expiration (권장하지 않음)
   ```

3. **권한 선택 (Scopes):**
   ```
   ✅ repo (전체 체크)
      ✅ repo:status
      ✅ repo_deployment
      ✅ public_repo
      ✅ repo:invite
      ✅ security_events

   ✅ admin:repo_hook (전체 체크)
      ✅ write:repo_hook
      ✅ read:repo_hook
   ```

4. 페이지 맨 아래 **Generate token** 클릭

### 1-4. 토큰 복사 및 저장

⚠️ **중요:** 생성된 토큰은 **딱 한 번만** 볼 수 있습니다!

```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

- 안전한 곳에 복사해두세요 (메모장, 비밀번호 관리자 등)
- 토큰을 잃어버리면 재생성해야 합니다

---

## 2단계: Jenkins Credentials 추가

GitHub 접근을 위한 **2개의 Credentials**를 추가합니다.

### 2-1. Credential 추가 화면 이동

1. Jenkins 대시보드 → **Manage Jenkins**
2. **Security** 섹션 → **Credentials**
3. **Stores scoped to Jenkins** → **(global)** 클릭
4. 왼쪽 메뉴 **Add Credentials** 클릭

### 2-2. Credential #1: GitHub API용 (Secret text)

**용도:** GitHub Server 설정, Webhook 관리

```
Kind: Secret text

Scope: Global (Jenkins, nodes, items, all child items, etc)

Secret: [GitHub PAT 토큰 붙여넣기]
예: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

ID: github-pat

Description: GitHub Personal Access Token for API
```

**Create** 클릭

### 2-3. Credential #2: Git 리포지토리 접근용 (Username with password)

**용도:** Pipeline에서 Git clone/pull

다시 **Add Credentials** 클릭 후:

```
Kind: Username with password

Scope: Global (Jenkins, nodes, items, all child items, etc)

Username: [GitHub 사용자명]
예: JSJ2337

Password: [GitHub PAT 토큰 붙여넣기]
(동일한 토큰 사용 가능)

ID: github-repo-access

Description: GitHub Repository Access
```

**Create** 클릭

### 2-4. 생성 확인

**Credentials** → **(global)** 페이지에서 다음 2개가 보여야 합니다:

| ID | Kind | Description |
|----|------|-------------|
| github-pat | Secret text | GitHub Personal Access Token for API |
| github-repo-access | Username with password | GitHub Repository Access |

---

## 3단계: GitHub Server 설정

Jenkins와 GitHub API를 연결합니다.

### 3-1. System 설정 페이지 이동

1. **Manage Jenkins** → **System** 클릭
2. 스크롤하여 **GitHub** 섹션 찾기

### 3-2. GitHub Server 추가

1. **Add GitHub Server** 버튼 클릭
2. **GitHub Server** 선택

### 3-3. 설정 입력

```
Name: GitHub
(서버 이름 - 기본값 사용)

API URL: https://api.github.com
(기본값 - GitHub Enterprise가 아니면 변경 불필요)

Credentials: github-pat
(드롭다운에서 선택)

☑ Manage hooks
(자동으로 Webhook 관리 - 체크 권장)
```

### 3-4. 연결 테스트

1. **Test connection** 버튼 클릭
2. 성공 메시지 확인:
   ```
   Credentials verified for user [사용자명], rate limit: xxxxx
   ```
3. 에러 발생 시 Credential과 토큰 권한 확인

### 3-5. 저장

페이지 맨 아래 **Save** 버튼 클릭

---

## 4단계: Pipeline Job 생성

GitHub 리포지토리와 연결된 Pipeline을 만듭니다.

### 4-1. 새 Item 생성

1. Jenkins 대시보드 → **New Item** 클릭
2. 설정:
   ```
   Enter an item name: [Job 이름]
   예: JSJ-engineering-diary

   선택: Pipeline
   ```
3. **OK** 클릭

### 4-2. General 섹션

```
☑ GitHub project

Project url: [GitHub 리포지토리 URL]
예: https://github.com/JSJ2337/JSJ_engineering_Diary/
```

### 4-3. Build Triggers 섹션

```
☑ GitHub hook trigger for GITScm polling
```

이 옵션을 체크하면 GitHub Webhook으로 자동 빌드가 트리거됩니다.

### 4-4. Pipeline 섹션

#### Definition 설정

```
Definition: Pipeline script from SCM
```

#### SCM 설정

```
SCM: Git
```

#### Repositories 설정

```
Repository URL: [GitHub 리포지토리 .git URL]
예: https://github.com/JSJ2337/JSJ_engineering_Diary.git

Credentials: github-repo-access
(드롭다운에서 선택)
```

**중요:** URL 입력 후 에러가 사라지는지 확인
- ✅ 정상: 에러 메시지 없음
- ❌ 실패: "Failed to connect to repository" 에러
  → Credential 확인 필요

#### Branches to build

```
Branch Specifier (blank for 'any'): */main
```

**참고:** 리포지토리의 기본 브랜치에 따라 변경
- `*/main` (최근 리포지토리)
- `*/master` (구 리포지토리)
- `*/develop` (개발 브랜치)

#### Script Path

```
Script Path: Jenkinsfile
```

리포지토리 루트에 `Jenkinsfile`이 있어야 합니다.

### 4-5. 저장 및 테스트

1. **Save** 클릭
2. **Build Now** 클릭하여 수동 빌드 테스트
3. 빌드 결과 확인

---

## 5단계: GitHub Webhook 설정

Push 시 자동으로 Jenkins 빌드가 실행되도록 설정합니다.

### 5-1. ngrok URL 확인

Webhook에 사용할 Jenkins URL을 확인합니다:

```bash
# 명령어로 확인
curl -s http://localhost:4040/api/tunnels | grep public_url

# 또는 브라우저에서
http://localhost:4040
```

출력 예시:
```
https://7c60bf2f2491.ngrok-free.app
```

### 5-2. GitHub 리포지토리 Settings 이동

⚠️ **주의:** 개인 계정 Settings가 아닌 **리포지토리 Settings**

1. GitHub 리포지토리 페이지 접속
   ```
   예: https://github.com/JSJ2337/JSJ_engineering_Diary
   ```

2. 상단 탭에서 **Settings** 클릭
   ```
   Code | Issues | Pull requests | Actions | Projects | Wiki | Settings
                                                                  ↑ 여기!
   ```

3. 왼쪽 메뉴에서 **Webhooks** 클릭
   ```
   Code and automation
     Branches
     Tags
     Actions
     Webhooks  ← 여기!
     Environments
   ```

### 5-3. Webhook 추가

1. **Add webhook** 버튼 클릭 (초록색)

2. **Webhook 설정 입력:**

   ```
   Payload URL: https://[ngrok-url]/github-webhook/
   예: https://7c60bf2f2491.ngrok-free.app/github-webhook/

   ⚠️ 주의사항:
   - /github-webhook/ 경로 필수
   - 마지막 슬래시(/) 포함
   - https:// 프로토콜 사용

   Content type: application/json

   Secret: (비워두기)

   SSL verification: Enable SSL verification
   (기본값 - ngrok은 유효한 SSL 인증서 사용)
   ```

3. **Which events would you like to trigger this webhook?**
   ```
   ◉ Just the push event
   ```

4. **Active 확인:**
   ```
   ☑ Active
   ```

5. **Add webhook** 버튼 클릭 (페이지 하단)

### 5-4. Webhook 상태 확인

Webhook 목록 페이지로 이동하면:

**성공:**
```
✓ https://7c60bf2f2491.ngrok-free.app/github-webhook/
```

**실패:**
```
✗ https://7c60bf2f2491.ngrok-free.app/github-webhook/
```

### 5-5. Webhook 테스트

1. Webhook 클릭
2. **Recent Deliveries** 탭 확인
3. 초록 체크마크와 200 응답 코드 확인

---

## 테스트 및 확인

### 자동 빌드 테스트

1. **리포지토리에서 파일 수정:**
   ```bash
   # README.md 수정
   echo "Test webhook" >> README.md
   git add README.md
   git commit -m "Test: webhook trigger"
   git push origin main
   ```

2. **Jenkins 확인:**
   - Jenkins 대시보드로 이동
   - Pipeline Job이 자동으로 실행되는지 확인
   - Build History에서 #2, #3... 번호 증가 확인

3. **빌드 로그 확인:**
   - 빌드 번호 클릭 → **Console Output**
   - "Started by GitHub push by [사용자명]" 메시지 확인

### Webhook 전달 확인

GitHub 리포지토리:

1. **Settings** → **Webhooks** → Webhook 클릭
2. **Recent Deliveries** 탭
3. 최근 요청 확인:
   - ✅ 200 응답: 성공
   - ❌ 4xx/5xx 응답: 실패

---

## 문제 해결

### Credential이 드롭다운에 안 보임

**문제:** GitHub Server 또는 Pipeline 설정에서 Credential이 안 보임

**원인:**
- GitHub Server: Secret text 타입만 인식
- Pipeline: Username with password 타입 필요

**해결:**
1. Credentials → (global) 이동
2. 올바른 Kind로 다시 생성
3. 페이지 새로고침

### Git 리포지토리 연결 실패

**에러:**
```
Failed to connect to repository
Authentication failed
```

**해결:**
1. Credential에 사용한 토큰 권한 확인 (`repo` 권한 필요)
2. Repository URL이 `.git`으로 끝나는지 확인
3. Private 리포지토리인 경우 토큰 권한 재확인

### Webhook이 작동하지 않음

**증상:** Push했는데 Jenkins 빌드가 자동 실행 안 됨

**확인사항:**
1. **Webhook URL 확인:**
   ```
   ✅ https://[ngrok-url]/github-webhook/
   ❌ https://[ngrok-url]/github-webhook  (슬래시 없음)
   ❌ http://localhost:8080/github-webhook/  (로컬 URL)
   ```

2. **ngrok 실행 상태:**
   ```bash
   docker ps | grep ngrok
   curl http://localhost:4040/api/tunnels
   ```

3. **Jenkins 설정:**
   - Pipeline Job → Configure
   - "GitHub hook trigger for GITScm polling" 체크 확인

4. **GitHub Webhook Recent Deliveries:**
   - 200 응답: Jenkins 문제
   - 4xx/5xx 응답: 네트워크/URL 문제

### Webhook에서 빨간 X 표시

**원인 1: ngrok URL 변경**
```
ngrok 무료 버전은 재시작 시 URL 변경됨
```

**해결:**
```bash
# 새 ngrok URL 확인
curl -s http://localhost:4040/api/tunnels | grep public_url

# GitHub Webhook URL 업데이트
Settings → Webhooks → Edit
```

**원인 2: Jenkins 접속 불가**
```
Jenkins가 중지되었거나 ngrok이 꺼짐
```

**해결:**
```bash
# Jenkins 상태 확인
docker ps | grep jsj-jenkins

# ngrok 상태 확인
docker ps | grep jsj-jenkins-ngrok

# 재시작
docker-compose -f jsj_jenkins.yaml restart
docker-compose -f jsj_ngrok.yaml restart
```

---

## 보안 고려사항

### Personal Access Token 관리

⚠️ **주의사항:**
- 토큰을 코드에 직접 넣지 마세요
- 토큰을 Git 리포지토리에 커밋하지 마세요
- 주기적으로 토큰을 갱신하세요
- 사용하지 않는 토큰은 삭제하세요

### Webhook Secret 사용 (권장)

더 높은 보안을 위해 Webhook Secret 설정:

1. **Secret 생성:**
   ```bash
   openssl rand -hex 20
   ```

2. **GitHub Webhook 설정:**
   ```
   Secret: [생성된 secret]
   ```

3. **Jenkins에서 검증 설정**
   - Manage Jenkins → System → GitHub
   - Override Hook URL 설정

### ngrok 사용 시 주의사항

⚠️ **보안 위험:**
- Jenkins가 공개 인터넷에 노출됨
- 강력한 관리자 비밀번호 필수
- Jenkins Security 설정 강화 권장

**프로덕션 환경:**
- 고정 도메인 사용
- HTTPS 인증서 적용
- 방화벽 규칙 설정
- VPN 또는 IP 화이트리스트 고려

---

## 참고 자료

- [GitHub Webhooks 공식 문서](https://docs.github.com/en/webhooks)
- [Jenkins GitHub Plugin](https://plugins.jenkins.io/github/)
- [Jenkins Pipeline 문서](https://www.jenkins.io/doc/book/pipeline/)

---

**마지막 업데이트:** 2025-11-05
