# Jenkins & GitLab Docker 설정

Docker Compose를 사용한 Jenkins와 GitLab 컨테이너 설정 및 관리 프로젝트입니다.

## 목차

- [프로젝트 구조](#프로젝트-구조)
- [필수 요구사항](#필수-요구사항)
- [빠른 시작](#빠른-시작)
- [각 설정 파일 설명](#각-설정-파일-설명)
- [환경 변수 설정](#환경-변수-설정)
- [사용 방법](#사용-방법)
- [포트 정보](#포트-정보)
- [데이터 관리](#데이터-관리)
- [문제 해결](#문제-해결)
- [보안 주의사항](#보안-주의사항)

## 프로젝트 구조

```
jenkins_docker/
├── jsj_jenkins.yaml              # 기본 Jenkins 설정
├── jsj_jenkins_ngrok.yaml        # Jenkins + ngrok 통합 설정
├── jsj_gitlab.yaml               # GitLab CE (공식 이미지, x86)
├── jsj_gitlab2.yaml              # GitLab (비공식 ARM 이미지 - zengxs)
├── jsj_gitlab3.yaml              # GitLab (비공식 ARM 이미지 - ravermeister)
├── .env.example                  # 환경 변수 예시 파일
├── .gitignore                    # Git 제외 파일 목록
└── README.md                     # 이 문서
```

### 생성될 데이터 디렉터리

```
jenkins_docker/
├── jenkins-data/
│   └── jenkins_home/            # Jenkins 모든 데이터 (설정, 빌드, 플러그인 등)
└── gitlab-data/
    ├── config/                  # GitLab 설정
    ├── logs/                    # GitLab 로그
    └── gitlab_home/             # GitLab 데이터
```

## 필수 요구사항

- Docker Engine 20.10 이상
- Docker Compose 1.29 이상 (또는 Docker Compose V2)
- 최소 4GB RAM (Jenkins), 8GB 권장 (GitLab 포함 시)
- 최소 10GB 디스크 여유 공간

## 빠른 시작

### 1. 환경 변수 설정

```bash
# .env.example을 .env로 복사
cp .env.example .env

# .env 파일 편집 (UID/GID, ngrok token 등 설정)
nano .env  # 또는 vi, vim, code 등 원하는 에디터 사용
```

### 2. UID/GID 확인 및 설정

```bash
# 현재 사용자의 UID와 GID 확인
id -u  # UID 출력
id -g  # GID 출력

# .env 파일에 값 설정
# 예: UID=1000, GID=1000
```

### 3. Jenkins 실행

```bash
# 기본 Jenkins만 실행
docker-compose -f jsj_jenkins.yaml up -d

# Jenkins + ngrok 함께 실행 (외부 접속 필요 시)
docker-compose -f jsj_jenkins_ngrok.yaml up -d
```

### 4. 초기 Jenkins 비밀번호 확인

```bash
# Jenkins 초기 관리자 비밀번호 확인
docker exec jsj-jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword
```

## 각 설정 파일 설명

### jsj_jenkins.yaml

**용도**: 기본 Jenkins 서버 실행

**특징**:
- Jenkins LTS (Long Term Support) 버전 사용
- 로컬 네트워크에서만 접근 가능
- 포트: 8080 (웹 UI), 50000 (에이전트)

**실행**:
```bash
docker-compose -f jsj_jenkins.yaml up -d
```

**접속**: http://localhost:8080

---

### jsj_jenkins_ngrok.yaml

**용도**: Jenkins + ngrok을 함께 실행하여 외부에서 접속 가능

**특징**:
- Jenkins와 ngrok 컨테이너를 하나의 네트워크로 연결
- ngrok을 통해 인터넷에서 Jenkins에 접근 가능
- GitHub/GitLab Webhook 설정 가능

**사전 준비**:
1. [ngrok.com](https://ngrok.com) 가입
2. Authtoken 발급 (대시보드에서 확인)
3. `.env` 파일에 `NGROK_AUTHTOKEN` 설정

**실행**:
```bash
docker-compose -f jsj_jenkins_ngrok.yaml up -d
```

**ngrok URL 확인**:
```bash
# ngrok 웹 UI 접속
http://localhost:4040

# 또는 로그로 확인
docker logs jsj-jenkins-ngrok
```

---

### jsj_gitlab.yaml

**용도**: GitLab Community Edition 공식 이미지 (x86/amd64)

**특징**:
- 공식 GitLab CE 이미지 사용
- ARM Mac에서는 에뮬레이션으로 실행 (platform: linux/amd64)
- 포트: 8088 (HTTP), 8443 (HTTPS), 2222 (SSH)

**실행**:
```bash
docker-compose -f jsj_gitlab.yaml up -d
```

**접속**: http://localhost:8088

**초기 root 비밀번호 확인**:
```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

---

### jsj_gitlab2.yaml / jsj_gitlab3.yaml

**용도**: ARM 아키텍처용 GitLab (비공식 이미지)

**주의**: 비공식 이미지이므로 프로덕션 환경에서는 권장하지 않음

**차이점**:
- `jsj_gitlab2.yaml`: zengxs/gitlab 이미지, 포트 8088
- `jsj_gitlab3.yaml`: ravermeister/gitlab 이미지, 포트 9090

## 환경 변수 설정

`.env` 파일에 다음 값을 설정하세요:

```bash
# 사용자 권한 설정 (필수)
UID=1000              # 'id -u' 명령으로 확인
GID=1000              # 'id -g' 명령으로 확인

# ngrok 설정 (jsj_jenkins_ngrok.yaml 사용 시 필수)
NGROK_AUTHTOKEN=your_ngrok_authtoken_here

# GitLab 설정 (선택사항)
GITLAB_ROOT_PASSWORD=changeme_gitlab_password
```

## 사용 방법

### Jenkins 관리

```bash
# 시작
docker-compose -f jsj_jenkins.yaml up -d

# 중지
docker-compose -f jsj_jenkins.yaml down

# 로그 확인
docker-compose -f jsj_jenkins.yaml logs -f

# 재시작
docker-compose -f jsj_jenkins.yaml restart
```

### GitLab 관리

```bash
# 시작 (원하는 버전 선택)
docker-compose -f jsj_gitlab.yaml up -d

# 중지
docker-compose -f jsj_gitlab.yaml down

# 로그 확인
docker-compose -f jsj_gitlab.yaml logs -f gitlab
```

### 데이터 백업

```bash
# Jenkins 데이터 백업
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz jenkins-data/

# GitLab 데이터 백업
docker exec -t gitlab gitlab-backup create

# 또는 전체 디렉터리 백업
tar -czf gitlab-backup-$(date +%Y%m%d).tar.gz gitlab-data/
```

### 전체 삭제 (데이터 포함)

```bash
# 컨테이너 중지 및 삭제
docker-compose -f jsj_jenkins.yaml down -v

# 데이터 디렉터리 삭제 (주의!)
rm -rf jenkins-data/
rm -rf gitlab-data/
```

## 포트 정보

### Jenkins

| 포트 | 용도 |
|------|------|
| 8080 | Jenkins 웹 UI |
| 50000 | Jenkins 에이전트 연결 (JNLP) |
| 4040 | ngrok 웹 UI (jsj_jenkins_ngrok.yaml 사용 시) |

### GitLab

| 파일 | HTTP | HTTPS | SSH |
|------|------|-------|-----|
| jsj_gitlab.yaml | 8088 | 8443 | 2222 |
| jsj_gitlab2.yaml | 8088 | 8443 | 2222 |
| jsj_gitlab3.yaml | 9090 | - | 2224 |

## 데이터 관리

### 볼륨 위치

모든 데이터는 호스트의 로컬 디렉터리에 저장됩니다:

- **Jenkins**: `./jenkins-data/jenkins_home/`
  - 플러그인, 작업(job) 설정, 빌드 히스토리 등

- **GitLab**: `./gitlab-data/`
  - 저장소, 사용자 데이터, CI/CD 설정 등

### 권한 문제 해결

UID/GID 설정으로 권한 문제를 방지하지만, 문제 발생 시:

```bash
# 현재 사용자 소유로 변경
sudo chown -R $(id -u):$(id -g) jenkins-data/
sudo chown -R $(id -u):$(id -g) gitlab-data/
```

## 문제 해결

### Jenkins가 시작되지 않을 때

```bash
# 로그 확인
docker logs jsj-jenkins-server

# 볼륨 권한 확인
ls -la jenkins-data/

# 컨테이너 재시작
docker restart jsj-jenkins-server
```

### GitLab이 느리게 시작될 때

GitLab은 초기 시작에 5-10분 정도 소요됩니다.

```bash
# 상태 확인
docker exec -it gitlab gitlab-ctl status

# 준비 상태 확인
docker logs gitlab
```

### ngrok이 연결되지 않을 때

```bash
# ngrok 로그 확인
docker logs jsj-jenkins-ngrok

# authtoken 확인
cat .env | grep NGROK

# ngrok 컨테이너 재시작
docker restart jsj-jenkins-ngrok
```

### 포트 충돌 문제

다른 서비스가 이미 포트를 사용 중일 때:

```bash
# 포트 사용 확인
sudo lsof -i :8080
sudo netstat -tulpn | grep 8080

# YAML 파일에서 포트 변경
# 예: "8081:8080" (호스트:컨테이너)
```

## 보안 주의사항

### 중요한 보안 수칙

1. **절대 .env 파일을 Git에 커밋하지 마세요**
   - ngrok authtoken 등 민감한 정보 포함
   - `.gitignore`에 이미 추가되어 있음

2. **초기 비밀번호 즉시 변경**
   - Jenkins: 초기 설정 시 관리자 계정 생성
   - GitLab: root 비밀번호 변경

3. **프로덕션 환경에서는**
   - HTTPS 설정 필수
   - 방화벽 규칙 적용
   - 정기적인 보안 업데이트

4. **ngrok 사용 시 주의**
   - 공개 인터넷에 노출됨
   - 강력한 인증 설정 필요
   - 임시 테스트 용도로만 사용 권장

### 권장 보안 설정

```bash
# Jenkins 보안 설정
# - Jenkins 관리 > Configure Global Security
# - "Allow users to sign up" 비활성화
# - Matrix-based security 활성화

# GitLab 보안 설정
# - Admin Area > Settings > General
# - Sign-up restrictions 설정
# - 2FA (Two-Factor Authentication) 활성화
```

## 업데이트 방법

### Jenkins 업데이트

```bash
# 최신 이미지 가져오기
docker pull jenkins/jenkins:lts

# 컨테이너 재생성
docker-compose -f jsj_jenkins.yaml down
docker-compose -f jsj_jenkins.yaml up -d
```

### GitLab 업데이트

```bash
# 백업 먼저!
docker exec -t gitlab gitlab-backup create

# 최신 이미지 가져오기
docker pull gitlab/gitlab-ce:latest

# 컨테이너 재생성
docker-compose -f jsj_gitlab.yaml down
docker-compose -f jsj_gitlab.yaml up -d
```

## 유용한 명령어 모음

```bash
# 모든 Jenkins 로그 실시간 보기
docker logs -f jsj-jenkins-server

# Jenkins 컨테이너 내부 접속
docker exec -it jsj-jenkins-server bash

# GitLab 헬스체크
docker exec -it gitlab gitlab-rake gitlab:check

# 디스크 사용량 확인
du -sh jenkins-data/ gitlab-data/

# 네트워크 확인
docker network ls
docker network inspect jenkins_default
```

## 참고 자료

- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- [Jenkins Docker Hub](https://hub.docker.com/r/jenkins/jenkins)
- [GitLab 공식 문서](https://docs.gitlab.com/)
- [ngrok 문서](https://ngrok.com/docs)
- [Docker Compose 문서](https://docs.docker.com/compose/)

## 라이선스

이 프로젝트의 설정 파일은 자유롭게 사용 가능합니다.

## 기여

버그 제보나 개선 사항이 있다면 이슈를 등록해주세요.

---

**마지막 업데이트**: 2025-11-05
**Jenkins LTS 버전**: 2.516.3
**GitLab CE 버전**: latest
