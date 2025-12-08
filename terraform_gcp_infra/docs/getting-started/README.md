# 🚀 Getting Started

처음 시작하는 분들을 위한 단계별 가이드입니다.

## 📖 가이드 순서

1. **[사전 요구사항](./prerequisites.md)** (5분)
   - Terraform, Terragrunt, gcloud 설치
   - GCP 인증 설정
   - 권한 확인

2. **[Bootstrap 설정](./bootstrap-setup.md)** (10분)
   - 중앙 State 관리 프로젝트 배포
   - Service Account 생성
   - 권한 설정

3. **[첫 배포](./first-deployment.md)** (30분)
   - 템플릿 복사
   - 9개 레이어 순차 배포
   - 리소스 확인

4. **[자주 쓰는 명령어](./quick-commands.md)** (참고용)
   - Terragrunt/gcloud 치트시트
   - 50+ 명령어

## 빠른 시작

```bash
# 1. Bootstrap 배포 (레이어 구조)
cd bootstrap/00-foundation
TG_USE_LOCAL_BACKEND=true terragrunt init
TG_USE_LOCAL_BACKEND=true terragrunt apply
terragrunt init -migrate-state  # GCS로 마이그레이션

# 2. 인증 설정
gcloud auth application-default set-quota-project delabs-gcp-mgmt

# 3. 첫 프로젝트 배포
cd environments/LIVE/gcp-gcby/00-project
terragrunt init
terragrunt apply
```

## 다음 단계

- [아키텍처 이해하기](../architecture/)
- [새 프로젝트 추가하기](../guides/adding-new-project.md)
- [Jenkins CI/CD 설정](../guides/jenkins-cicd.md)

---

[← 문서 포털로 돌아가기](../README.md)
