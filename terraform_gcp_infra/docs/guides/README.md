# Guides

특정 작업을 수행하기 위한 실용적인 가이드입니다.

## 가이드 목록

### [신규 프로젝트 생성](../CREATE_NEW_PROJECT.md) - 쉬움

- `create_project.sh` 스크립트 사용
- 템플릿 복사 및 자동 치환
- 생성 후 필수 설정

### [신규 프로젝트 추가 (고급)](./adding-new-project.md) - 보통

- Bootstrap 통합이 필요한 경우
- VPC Peering, PSC Endpoint 설정
- 중앙 DNS 연동

### [Terragrunt 사용법](./terragrunt-usage.md) - 보통

- 왜 Terragrunt를 사용하는가?
- 디렉터리 구조
- 기본 명령어
- 변수 병합 순서
- 의존성 관리

### [Jenkins CI/CD](./jenkins-cicd.md) - 고급

- Jenkins 설정
- GCP 인증
- Pipeline 구조
- 승인 프로세스
- 트러블슈팅

### [Jenkins GitHub 연동](./jenkins-github-setup.md) - 보통

- GitHub Webhook 설정
- Jenkins Pipeline 연동
- Credential 구성

### [모니터링 설정](./monitoring-setup.md) - 보통

- Cloud Monitoring 알림 정책
- Slack Webhook 연동
- 임계값 설정 가이드

### [Jenkins 템플릿 가이드](./jenkins-template.md) - 보통

- Jenkinsfile 구조 설명
- Phase 기반 배포 구성
- 변수 설정 방법

### [리소스 삭제](./destroy-guide.md) - 보통

- 안전한 삭제 순서
- Lien 제거
- State 정리
- 주의사항

## 사용 패턴

### 신규 환경 구축

1. [신규 프로젝트 생성](../CREATE_NEW_PROJECT.md)
2. [Terragrunt 사용법](./terragrunt-usage.md)

### CI/CD 자동화

1. [Jenkins CI/CD](./jenkins-cicd.md)
2. [Terragrunt 사용법](./terragrunt-usage.md)

### 환경 정리

1. [리소스 삭제](./destroy-guide.md)

## 참고 자료

- [시작 가이드](../getting-started/)
- [아키텍처](../architecture/)
- [트러블슈팅](../troubleshooting/)
- [예제 설정 파일](../examples/)

---

[← 문서 포털로 돌아가기](../README.md)
