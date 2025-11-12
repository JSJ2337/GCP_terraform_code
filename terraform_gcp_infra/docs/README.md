# 📚 문서 포털

GCP Terraform Infrastructure 프로젝트의 모든 문서를 한눈에 확인하세요.

## 🚀 시작하기 (5분 가이드)

새로 시작하시나요? 이 순서대로 읽어보세요:

1. [사전 요구사항](./getting-started/prerequisites.md) - 필수 도구 및 권한 (3분)
2. [Bootstrap 설정](./getting-started/bootstrap-setup.md) - 중앙 State 관리 설정 (10분)
3. [첫 배포](./getting-started/first-deployment.md) - 실제 프로젝트 배포 (30분)
4. [자주 쓰는 명령어](./getting-started/quick-commands.md) - 치트시트

## 📖 문서 카테고리

### 🏁 Getting Started (시작하기)

처음 사용하는 분들을 위한 단계별 가이드입니다.

| 문서 | 설명 | 소요 시간 |
|------|------|----------|
| [사전 요구사항](./getting-started/prerequisites.md) | Terraform, Terragrunt, gcloud 설치 | 5분 |
| [Bootstrap 설정](./getting-started/bootstrap-setup.md) | 중앙 State 관리 프로젝트 배포 | 10분 |
| [첫 배포](./getting-started/first-deployment.md) | 9개 레이어 순차 배포 가이드 | 30분 |
| [자주 쓰는 명령어](./getting-started/quick-commands.md) | Terragrunt/gcloud 치트시트 | - |

### 🏗️ Architecture (아키텍처)

시스템 구조와 설계 원칙을 이해하기 위한 문서입니다.

| 문서 | 설명 |
|------|------|
| [전체 구조](./architecture/overview.md) | 3-Tier 구조, 모듈, 레이어 설명 |
| [State 관리](./architecture/state-management.md) | 중앙 집중식 State 전략 |
| [네트워크 설계](./architecture/network-design.md) | DMZ/Private/DB 서브넷 구조 |
| [다이어그램 모음](./architecture/diagrams.md) | Mermaid 다이어그램 10개 |

### 📝 Guides (가이드)

특정 작업을 수행하기 위한 실용적인 가이드입니다.

| 문서 | 설명 | 난이도 |
|------|------|--------|
| [새 프로젝트 추가](./guides/adding-new-project.md) | 템플릿 복사 및 배포 | ⭐ 쉬움 |
| [Terragrunt 사용법](./guides/terragrunt-usage.md) | Terragrunt 완벽 가이드 | ⭐⭐ 보통 |
| [Jenkins CI/CD](./guides/jenkins-cicd.md) | Pipeline 자동화 | ⭐⭐⭐ 고급 |
| [리소스 삭제](./guides/destroy-guide.md) | 안전한 인프라 삭제 | ⭐⭐ 보통 |

### 🔧 Troubleshooting (트러블슈팅)

문제 발생 시 빠르게 해결하기 위한 문서입니다.

| 문서 | 설명 |
|------|------|
| [일반적인 오류](./troubleshooting/common-errors.md) | 15가지 자주 발생하는 오류 해결법 |
| [State 문제](./troubleshooting/state-issues.md) | State Lock, 손상, 복원 |
| [네트워크 문제](./troubleshooting/network-issues.md) | VPC, 방화벽, PSC 오류 |

### 📦 Modules (모듈)

재사용 가능한 11개 모듈의 상세 문서입니다.

| 모듈 | 설명 | 문서 |
|------|------|------|
| naming | 중앙 집중식 네이밍 | [README](../modules/naming/README.md) |
| project-base | GCP 프로젝트 생성 | [README](../modules/project-base/README.md) |
| network-dedicated-vpc | VPC 네트워킹 | [README](../modules/network-dedicated-vpc/README.md) |
| gcs-root | 다중 버킷 관리 | [README](../modules/gcs-root/README.md) |
| gcs-bucket | 단일 버킷 설정 | [README](../modules/gcs-bucket/README.md) |
| iam | IAM 바인딩 | [README](../modules/iam/README.md) |
| observability | Logging/Monitoring | [README](../modules/observability/README.md) |
| gce-vmset | VM 인스턴스 | [README](../modules/gce-vmset/README.md) |
| cloudsql-mysql | MySQL DB | [README](../modules/cloudsql-mysql/README.md) |
| memorystore-redis | Redis 캐시 | [README](../modules/memorystore-redis/README.md) |
| load-balancer | Load Balancer | [README](../modules/load-balancer/README.md) |

### 📜 Changelog (변경 이력)

프로젝트의 변경 사항과 작업 이력입니다.

| 문서 | 설명 |
|------|------|
| [CHANGELOG](./changelog/CHANGELOG.md) | 버전별 변경 내역 |
| [작업 이력 인덱스](./changelog/WORK_HISTORY_INDEX.md) | 📋 전체 작업 이력 인덱스 |
| [2025-11-12](./changelog/work-history/2025-11-12.md) | 최신: 문서 재구성 |
| [2025-11-11](./changelog/work-history/2025-11-11.md) | Terragrunt 0.93 적용 |
| [2025-11-10](./changelog/work-history/2025-11-10.md) | jsj-game-k 환경 생성 |
| [전체 이력 보기](./changelog/WORK_HISTORY_INDEX.md) | 모든 날짜별 작업 이력 |

## 🎯 시나리오별 가이드

### "처음 시작합니다"
1. [사전 요구사항](./getting-started/prerequisites.md)
2. [Bootstrap 설정](./getting-started/bootstrap-setup.md)
3. [첫 배포](./getting-started/first-deployment.md)

### "새 환경을 추가하고 싶어요"
1. [새 프로젝트 추가](./guides/adding-new-project.md)
2. [Terragrunt 사용법](./guides/terragrunt-usage.md)

### "오류가 발생했어요"
1. [일반적인 오류](./troubleshooting/common-errors.md) 확인
2. 해당 없으면 [State 문제](./troubleshooting/state-issues.md) 또는 [네트워크 문제](./troubleshooting/network-issues.md)
3. [GitHub Issues](https://github.com/your-org/terraform-gcp-infra/issues)

### "CI/CD를 설정하고 싶어요"
1. [Jenkins CI/CD 가이드](./guides/jenkins-cicd.md)
2. [Terragrunt 사용법](./guides/terragrunt-usage.md)

### "인프라를 삭제하고 싶어요"
1. [리소스 삭제 가이드](./guides/destroy-guide.md)

### "아키텍처를 이해하고 싶어요"
1. [전체 구조](./architecture/overview.md)
2. [다이어그램 모음](./architecture/diagrams.md)
3. [State 관리](./architecture/state-management.md)

## 🔍 빠른 검색

### 명령어를 찾으시나요?
→ [자주 쓰는 명령어](./getting-started/quick-commands.md)

### 오류 메시지가 나왔나요?
→ [일반적인 오류](./troubleshooting/common-errors.md)에서 Ctrl+F 검색

### 모듈 사용법이 궁금하신가요?
→ [Modules](#-modules-모듈) 섹션에서 해당 모듈 README 확인

### 배포 순서를 모르시겠나요?
→ [첫 배포](./getting-started/first-deployment.md)

## 📞 도움이 필요하신가요?

1. **문서 검색**: 이 포털에서 키워드 검색
2. **FAQ 확인**: [일반적인 오류](./troubleshooting/common-errors.md)
3. **이슈 등록**: [GitHub Issues](https://github.com/your-org/terraform-gcp-infra/issues)
4. **팀 연락**: Slack #infra-support 채널

## 🗂️ 아카이브

이전 버전 문서는 [archive/](./archive/) 디렉터리에서 확인할 수 있습니다.

---

**최종 업데이트**: 2025-11-12
**문서 버전**: 2.0 (재구성 완료)
