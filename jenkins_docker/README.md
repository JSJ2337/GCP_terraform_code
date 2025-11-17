# Jenkins Docker 설정

Docker Compose를 사용한 Jenkins 컨테이너 설정 및 관리 프로젝트입니다.

## 목차

- [프로젝트 구조](#프로젝트-구조)
- [필수 요구사항](#필수-요구사항)
- [빠른 시작](#빠른-시작)
- [상세 가이드](#상세-가이드)
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
├── jsj_jenkins.yaml              # Jenkins 서버 설정
├── jsj_ngrok.yaml                # ngrok 설정 (선택)
├── Dockerfile                    # Jenkins + Terraform + Terragrunt + Git
├── .env.example                  # 환경 변수 예시 파일
├── .gitignore                    # Git 제외 파일 목록
├── README.md                     # 이 문서 (프로젝트 개요)
├── JENKINS_SETUP.md              # Jenkins 초기 설정 가이드
├── GITHUB_INTEGRATION.md         # GitHub 연동 가이드
└── TERRAGRUNT_PIPELINE.md        # Terragrunt CI/CD Pipeline 가이드
```

### 생성될 데이터 디렉터리

```
jenkins_docker/
└── jenkins-data/
    └── jenkins_home/            # Jenkins 모든 데이터 (설정, 빌드, 플러그인 등)
```

## 필수 요구사항

- Docker Engine 20.10 이상
- Docker Compose 1.29 이상 (또는 Docker Compose V2)
- 최소 4GB RAM 권장
- 최소 10GB 디스크 여유 공간

## 빠른 시작

### 방법 1: Jenkins만 사용 (로컬 접속)

```bash
# 1. Jenkins 이미지 빌드 및 실행
docker-compose -f jsj_jenkins.yaml up -d --build

# 2. 초기 비밀번호 확인
docker exec jsj-jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword

# 3. 브라우저에서 http://localhost:8080 접속
```

### 방법 2: Jenkins + ngrok 사용 (외부 접속)

```bash
# 1. ngrok authtoken 설정
cp .env.example .env
# .env 파일 편집하여 NGROK_AUTHTOKEN 입력

# 2. Jenkins 실행
docker-compose -f jsj_jenkins.yaml up -d --build

# 3. ngrok 실행
docker-compose -f jsj_ngrok.yaml up -d

# 4. ngrok URL 확인
curl -s http://localhost:4040/api/tunnels | grep public_url
# 또는 브라우저에서 http://localhost:4040 접속

# 5. ngrok URL로 Jenkins 접속
```

---

## 상세 가이드

### 📘 [Jenkins 초기 설정](./JENKINS_SETUP.md)
Jenkins 컨테이너 실행 후 초기 설정 방법:
- 초기 관리자 비밀번호 확인
- 플러그인 설치
- 관리자 계정 생성
- Jenkins URL 설정

### 🔗 [GitHub 연동](./GITHUB_INTEGRATION.md)
Jenkins와 GitHub을 연동하는 방법:
- Personal Access Token 생성
- Credentials 설정
- GitHub Server 설정
- Pipeline Job 생성
- Webhook 설정

### 🚀 [Terragrunt CI/CD Pipeline](./TERRAGRUNT_PIPELINE.md)
Terragrunt 자동화 Pipeline 사용 방법:
- 승인 단계가 있는 안전한 배포
- Plan/Apply/Destroy 파라미터 제어
- 전체 스택 또는 개별 레이어 실행
- GCP Credentials 설정
- 실행 시나리오 및 모범 사례

---

## 각 설정 파일 설명

### jsj_jenkins.yaml

**용도**: Jenkins 서버 실행

**특징**:
- Terraform 1.13.5 + Terragrunt 0.93.3 + Git 사전 설치
- 로컬 bind mount 사용 (데이터 직접 접근 가능)
- 포트: 8080 (웹 UI), 50000 (에이전트)

**설치된 도구**:
- Jenkins LTS
- Terraform 1.13.5
- Terragrunt 0.93.3
- Git 2.47.3
- Google Cloud SDK (gcloud 547.0.0)
- Python 3.11

**실행**:
```bash
# 이미지 빌드 및 실행
docker-compose -f jsj_jenkins.yaml up -d --build

# 실행만 (이미 빌드된 경우)
docker-compose -f jsj_jenkins.yaml up -d
```

**접속**: http://localhost:8080

---

### jsj_ngrok.yaml

**용도**: ngrok을 통한 외부 접속 제공 (Jenkins와 별도 실행)

**특징**:
- Jenkins 네트워크에 연결
- GitHub/GitLab Webhook 설정 가능
- Jenkins와 독립적으로 시작/중지 가능

**사전 준비**:
1. [ngrok.com](https://ngrok.com) 가입
2. Authtoken 발급 ([대시보드](https://dashboard.ngrok.com/get-started/your-authtoken))
3. `.env` 파일 생성 및 `NGROK_AUTHTOKEN` 설정

**실행 순서**:
```bash
# 1. Jenkins 먼저 시작
docker-compose -f jsj_jenkins.yaml up -d

# 2. ngrok 시작
docker-compose -f jsj_ngrok.yaml up -d
```

**ngrok URL 확인**:
```bash
# 웹 UI에서 확인
http://localhost:4040

# 명령어로 확인
curl -s http://localhost:4040/api/tunnels | grep public_url

# 로그로 확인
docker logs jsj-jenkins-ngrok
```

## 환경 변수 설정

ngrok을 사용할 경우에만 `.env` 파일이 필요합니다:

```bash
# .env.example을 .env로 복사
cp .env.example .env

# .env 파일 편집
nano .env
```

**필요한 변수**:
```bash
# ngrok 설정 (jsj_ngrok.yaml 사용 시 필수)
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
```

**참고**: UID/GID 설정은 제거되었습니다. Jenkins가 기본 사용자로 실행됩니다.

## 사용 방법

### Jenkins 관리

```bash
# 시작 (이미지 빌드 포함)
docker-compose -f jsj_jenkins.yaml up -d --build

# 시작 (빌드 스킵)
docker-compose -f jsj_jenkins.yaml up -d

# 중지
docker-compose -f jsj_jenkins.yaml down

# 로그 확인
docker-compose -f jsj_jenkins.yaml logs -f

# 재시작
docker-compose -f jsj_jenkins.yaml restart
```

### ngrok 관리

```bash
# 시작 (Jenkins가 먼저 실행 중이어야 함)
docker-compose -f jsj_ngrok.yaml up -d

# 중지
docker-compose -f jsj_ngrok.yaml down

# 로그 확인
docker logs -f jsj-jenkins-ngrok
```

### 전체 시작/중지

```bash
# 전체 시작
docker-compose -f jsj_jenkins.yaml up -d --build
docker-compose -f jsj_ngrok.yaml up -d

# 전체 중지
docker-compose -f jsj_ngrok.yaml down
docker-compose -f jsj_jenkins.yaml down
```

### 데이터 백업

```bash
# Jenkins 데이터 백업
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz jenkins-data/
```

### 전체 삭제 (데이터 포함)

```bash
# 컨테이너 중지 및 삭제
docker-compose -f jsj_jenkins.yaml down -v

# 데이터 디렉터리 삭제 (주의!)
rm -rf jenkins-data/
```

## 포트 정보

### Jenkins

| 포트 | 용도 | 파일 |
|------|------|------|
| 8080 | Jenkins 웹 UI | jsj_jenkins.yaml |
| 50000 | Jenkins 에이전트 연결 (JNLP) | jsj_jenkins.yaml |
| 4040 | ngrok 웹 UI | jsj_ngrok.yaml |

## 데이터 관리

### 볼륨 위치

모든 데이터는 호스트의 로컬 디렉터리에 저장됩니다:

- **Jenkins**: `./jenkins-data/jenkins_home/`
  - 플러그인, 작업(job) 설정, 빌드 히스토리 등

### 권한 문제

Jenkins는 컨테이너 내부의 기본 사용자(jenkins)로 실행됩니다.
WSL2 환경에서는 파일 권한이 자동으로 관리되므로 별도 설정이 필요 없습니다.

**만약 권한 문제 발생 시**:
```bash
# Jenkins 컨테이너를 재시작하면 자동으로 권한이 설정됨
docker-compose -f jsj_jenkins.yaml restart
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

### ngrok이 연결되지 않을 때

```bash
# Jenkins가 먼저 실행 중인지 확인
docker ps | grep jsj-jenkins-server

# ngrok 로그 확인
docker logs jsj-jenkins-ngrok

# authtoken 확인
cat .env | grep NGROK

# ngrok 재시작
docker-compose -f jsj_ngrok.yaml restart

# 네트워크 확인
docker network inspect jenkins_docker_jenkins_default
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
```

## 업데이트 방법

### Jenkins/Terraform/Terragrunt 버전 업데이트

Dockerfile에서 버전을 수정한 후:

```bash
# 이미지 재빌드
docker-compose -f jsj_jenkins.yaml down
docker-compose -f jsj_jenkins.yaml up -d --build

# 설치된 버전 확인
docker exec jsj-jenkins-server terraform --version
docker exec jsj-jenkins-server terragrunt --version
docker exec jsj-jenkins-server git --version
```

## 유용한 명령어 모음

```bash
# 모든 Jenkins 로그 실시간 보기
docker logs -f jsj-jenkins-server

# Jenkins 컨테이너 내부 접속
docker exec -it jsj-jenkins-server bash

# 디스크 사용량 확인
du -sh jenkins-data/

# 네트워크 확인
docker network ls
docker network inspect jenkins_default
```

## 참고 자료

### 프로젝트 문서
- [Jenkins 초기 설정 가이드](./JENKINS_SETUP.md)
- [GitHub 연동 가이드](./GITHUB_INTEGRATION.md)
- [Terragrunt CI/CD Pipeline 가이드](./TERRAGRUNT_PIPELINE.md)

### 외부 문서
- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- [Jenkins Docker Hub](https://hub.docker.com/r/jenkins/jenkins)
- [Terraform 문서](https://www.terraform.io/docs)
- [Terragrunt 문서](https://terragrunt.gruntwork.io/docs/)
- [ngrok 문서](https://ngrok.com/docs)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)

## 라이선스

이 프로젝트의 설정 파일은 자유롭게 사용 가능합니다.

## 기여

버그 제보나 개선 사항이 있다면 이슈를 등록해주세요.

## 빠른 GitHub 연동

상세한 내용은 [GITHUB_INTEGRATION.md](./GITHUB_INTEGRATION.md)를 참조하세요.

### 요약
1. **GitHub Token 생성**: Settings → Developer settings → Tokens
2. **Jenkins Credentials 추가**: 2개 필요 (Secret text + Username/Password)
3. **GitHub Server 설정**: Manage Jenkins → System → GitHub
4. **Pipeline Job 생성**: New Item → Pipeline → SCM 연결
5. **Webhook 설정**: GitHub 리포지토리 → Settings → Webhooks

---

**마지막 업데이트**: 2025-11-05
**Jenkins LTS 버전**: 2.528.1
**Terraform 버전**: 1.13.5
**Terragrunt 버전**: 0.93.3
