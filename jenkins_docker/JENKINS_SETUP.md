# Jenkins 초기 설정 가이드

Jenkins 컨테이너 실행 후 초기 설정 및 구성 방법을 설명합니다.

## 목차

- [Jenkins 초기 접속](#jenkins-초기-접속)
- [초기 관리자 비밀번호 확인](#초기-관리자-비밀번호-확인)
- [플러그인 설치](#플러그인-설치)
- [관리자 계정 생성](#관리자-계정-생성)
- [Jenkins URL 설정](#jenkins-url-설정)
- [추가 플러그인 설치](#추가-플러그인-설치)
- [설치 확인](#설치-확인)

---

## Jenkins 초기 접속

### 로컬 접속
```
http://localhost:8080
```

### 외부 접속 (ngrok 사용 시)
```bash
# ngrok URL 확인
curl -s http://localhost:4040/api/tunnels | grep public_url

# 또는 브라우저에서
http://localhost:4040
```

---

## 초기 관리자 비밀번호 확인

### 방법 1: Docker 명령어 (권장)
```bash
docker exec jsj-jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword
```

### 방법 2: 로그 확인
```bash
docker logs jsj-jenkins-server | grep -A 5 "initial admin password"
```

### 방법 3: 파일 직접 확인 (bind mount 사용 시)
```bash
cat jenkins-data/jenkins_home/secrets/initialAdminPassword
```

복사한 비밀번호를 Jenkins 웹 UI의 "Administrator password" 필드에 입력합니다.

---

## 플러그인 설치

초기 화면에서 두 가지 옵션이 제공됩니다:

### 옵션 1: Install suggested plugins (권장)

**장점:**
- 가장 많이 사용하는 플러그인 자동 설치
- Git, GitHub 기본 플러그인 포함
- 빠르고 간편

**포함되는 주요 플러그인:**
- Git plugin
- GitHub plugin
- Pipeline
- Credentials Plugin
- SSH Agent
- Workspace Cleanup
- 기타 필수 플러그인 다수

**선택 방법:**
1. "Install suggested plugins" 버튼 클릭
2. 플러그인 설치 완료 대기 (5-10분)
3. 일부 실패해도 괜찮음 (나중에 재설치 가능)

### 옵션 2: Select plugins to install (고급)

필요한 플러그인만 선택하여 설치합니다.

**최소 필수 플러그인:**
```
✅ Git
✅ GitHub
✅ GitHub Integration Plugin
✅ Credentials
✅ Credentials Binding
✅ Pipeline
✅ Workspace Cleanup
```

---

## 관리자 계정 생성

플러그인 설치가 완료되면 관리자 계정을 생성합니다.

### 입력 정보

```
Username: [원하는 사용자명]
예: admin, 본인 이름 등

Password: [강력한 비밀번호]
보안을 위해 복잡한 비밀번호 사용 권장

Confirm password: [비밀번호 재입력]

Full name: [전체 이름]
예: John Doe

Email address: [이메일 주소]
예: admin@example.com
```

### 중요 사항

⚠️ **계정 정보를 반드시 기록해두세요!**
- 이 정보로 Jenkins에 로그인합니다
- 비밀번호 분실 시 복구가 어려울 수 있습니다

입력 완료 후 **Save and Continue** 클릭

---

## Jenkins URL 설정

### Jenkins URL 입력

다음 화면에서 Jenkins URL을 설정합니다:

**로컬 환경:**
```
http://localhost:8080
```

**ngrok 사용 (외부 접속):**
```
https://your-ngrok-url.ngrok-free.app
```

### 주의사항

- ngrok URL은 재시작 시 변경될 수 있습니다 (무료 버전)
- 나중에 **Manage Jenkins** → **System**에서 변경 가능
- GitHub Webhook 사용 시 ngrok URL 사용 권장

**Save and Finish** 클릭

---

## 추가 플러그인 설치

초기 설정 완료 후 추가 플러그인을 설치할 수 있습니다.

### Terraform 관련 플러그인 (권장)

1. **Manage Jenkins** → **Plugins** → **Available plugins**

2. 검색 및 설치:
   ```
   ✅ Terraform Plugin
      - Terraform 명령어 쉽게 실행
      - Terraform 버전 관리

   ✅ AnsiColor
      - Terraform 출력에 컬러 추가
      - 가독성 향상
   ```

3. 체크박스 선택 후 **Install without restart** 또는 **Install** 클릭

### 기타 유용한 플러그인

```
⭕ Blue Ocean
   - 현대적이고 직관적인 UI
   - Pipeline 시각화 개선

⭕ Configuration as Code (JCasC)
   - YAML로 Jenkins 설정 관리
   - 설정 버전 관리 가능

⭕ Email Extension Plugin
   - 이메일 알림 고급 설정
   - 빌드 결과 통보

⭕ Slack Notification
   - Slack 채널에 빌드 알림
   - 팀 협업 시 유용

⭕ Docker Pipeline
   - Docker 명령어 Pipeline에서 사용
   - Docker 기반 빌드 시 필요
```

### 플러그인 업데이트

정기적으로 플러그인을 업데이트하세요:

1. **Manage Jenkins** → **Plugins** → **Updates**
2. 업데이트 가능한 플러그인 확인
3. 선택 후 **Download now and install after restart**

---

## 설치 확인

### Jenkins 버전 확인

**Manage Jenkins** → 페이지 하단에서 확인
```
Jenkins ver. 2.528.1
```

### 설치된 도구 확인

Jenkins 컨테이너에는 다음 도구가 사전 설치되어 있습니다:

```bash
# Terraform 버전 확인
docker exec jsj-jenkins-server terraform --version
# 출력: Terraform v1.9.8

# Terragrunt 버전 확인
docker exec jsj-jenkins-server terragrunt --version
# 출력: terragrunt version v0.68.15

# Git 버전 확인
docker exec jsj-jenkins-server git --version
# 출력: git version 2.47.3
```

### 플러그인 설치 확인

**Manage Jenkins** → **Plugins** → **Installed plugins**

주요 플러그인 확인:
- Git plugin
- GitHub plugin
- GitHub Integration Plugin
- Pipeline
- Credentials Plugin

---

## 다음 단계

✅ Jenkins 초기 설정 완료!

이제 다음 작업을 진행할 수 있습니다:
- [GitHub 연동](./GITHUB_INTEGRATION.md)
- Pipeline Job 생성
- Terraform/Terragrunt 자동화 설정

---

## 문제 해결

### 플러그인 설치 실패

**증상:** 플러그인 설치 중 일부 실패

**해결:**
```bash
# Jenkins 로그 확인
docker logs jsj-jenkins-server

# Jenkins 재시작
docker restart jsj-jenkins-server

# 실패한 플러그인 수동 재설치
Manage Jenkins → Plugins → Available plugins
```

### 초기 비밀번호를 찾을 수 없음

**증상:** initialAdminPassword 파일이 없음

**해결:**
```bash
# 컨테이너 재시작
docker restart jsj-jenkins-server

# 로그에서 비밀번호 확인
docker logs jsj-jenkins-server 2>&1 | grep -A 5 "password"
```

### 접속이 안 됨

**증상:** http://localhost:8080 접속 실패

**해결:**
```bash
# 컨테이너 실행 상태 확인
docker ps | grep jsj-jenkins-server

# 포트 확인
docker port jsj-jenkins-server

# 로그 확인
docker logs jsj-jenkins-server --tail 50
```

---

**마지막 업데이트:** 2025-11-05
