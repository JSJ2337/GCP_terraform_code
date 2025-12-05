# GCP Terraform Infrastructure - 기술 문서

본 문서는 GCP Terraform Infrastructure 프로젝트의 기술 문서 저장소입니다.

---

## 문서 구성

본 저장소는 인프라 구축, 운영, 유지보수를 위한 기술 문서로 구성되어 있습니다.

### 1. 초기 구축 가이드

인프라 초기 구축을 위한 기본 설정 및 배포 절차를 제공합니다.

| 문서 | 내용 | 예상 소요 시간 |
|------|------|---------------|
| [사전 요구사항](./getting-started/prerequisites.md) | 필수 도구 설치 및 권한 설정 | 5분 |
| [Bootstrap 구성](./getting-started/bootstrap-setup.md) | 중앙 State 관리 인프라 배포 | 10분 |
| [첫 번째 환경 배포](./getting-started/first-deployment.md) | 9개 레이어 순차 배포 절차 | 30분 |
| [명령어 참조](./getting-started/quick-commands.md) | Terragrunt/gcloud 명령어 모음 | - |

### 2. 아키텍처 설계

시스템 구조 및 설계 원칙에 대한 상세 문서입니다.

| 문서 | 내용 |
|------|------|
| [시스템 구조](./architecture/overview.md) | 3-Tier 아키텍처, 모듈 구성, 레이어 설명 |
| [State 관리 체계](./architecture/state-management.md) | 중앙 집중식 State 관리 전략 및 구현 |
| [네트워크 설계](./architecture/network-design.md) | DMZ/Private/DB 3계층 서브넷 구조 |
| [시스템 다이어그램](./architecture/diagrams.md) | Mermaid 기반 시각화 자료 (10종) |

### 3. 운영 가이드

실제 운영 환경에서 수행하는 작업별 절차서입니다.

| 문서 | 내용 | 복잡도 |
|------|------|--------|
| [신규 프로젝트 추가](./guides/adding-new-project.md) | 템플릿 기반 환경 생성 절차 | 하 |
| [Terragrunt 운영](./guides/terragrunt-usage.md) | Terragrunt 기반 인프라 관리 방법 | 중 |
| [Jenkins CI/CD 구성](./guides/jenkins-cicd.md) | 자동화 파이프라인 구축 및 운영 | 상 |
| [인프라 삭제 절차](./guides/destroy-guide.md) | 리소스 안전 제거 가이드 | 중 |

### 4. 장애 대응

장애 발생 시 대응 방법 및 해결 절차를 제공합니다.

| 문서 | 내용 |
|------|------|
| [일반 오류 대응](./troubleshooting/common-errors.md) | 빈번하게 발생하는 15가지 오류 및 해결 방법 |
| [State 관련 장애](./troubleshooting/state-issues.md) | State Lock, 손상, 복구 절차 |
| [네트워크 장애](./troubleshooting/network-issues.md) | VPC, 방화벽, PSC 관련 문제 해결 |

### 5. 모듈 문서

재사용 가능한 Terraform 모듈별 상세 스펙입니다.

| 모듈 | 기능 | 문서 |
|------|------|------|
| naming | 중앙 집중식 네이밍 규칙 관리 | [naming.md](./modules/naming.md) |
| project-base | GCP 프로젝트 생성 및 기본 설정 | [project-base.md](./modules/project-base.md) |
| network-dedicated-vpc | VPC 네트워크 구성 | [network-dedicated-vpc.md](./modules/network-dedicated-vpc.md) |
| cloud-dns | Cloud DNS Zone 및 레코드 관리 | [cloud-dns.md](./modules/cloud-dns.md) |
| gcs-root | 다중 GCS 버킷 관리 | [gcs-root.md](./modules/gcs-root.md) |
| gcs-bucket | 단일 GCS 버킷 상세 설정 | [gcs-bucket.md](./modules/gcs-bucket.md) |
| iam | IAM 바인딩 및 서비스 계정 관리 | [iam.md](./modules/iam.md) |
| observability | Logging 및 Monitoring 구성 | [observability.md](./modules/observability.md) |
| gce-vmset | Compute Engine VM 인스턴스 관리 | [gce-vmset.md](./modules/gce-vmset.md) |
| cloudsql-mysql | Cloud SQL MySQL 데이터베이스 | [cloudsql-mysql.md](./modules/cloudsql-mysql.md) |
| memorystore-redis | Memorystore Redis 캐시 | [memorystore-redis.md](./modules/memorystore-redis.md) |
| load-balancer | HTTP(S) 및 Internal Load Balancer | [load-balancer.md](./modules/load-balancer.md) |

> 전체 모듈 목록: [modules/README.md](./modules/README.md)

### 6. 변경 이력

프로젝트 변경 사항 및 작업 이력 기록입니다.

| 문서 | 내용 |
|------|------|
| [CHANGELOG](./changelog/CHANGELOG.md) | 버전별 변경 내역 및 마이그레이션 가이드 |
| [작업 이력](./changelog/work_history/README.md) | 날짜별 작업 요약 및 마일스톤 |
| [2025-11-21](./changelog/work_history/2025-11-21.md) | 최신: Jenkinsfile Phase 기반 구조 전환 + 서브넷/스토리지 자동화 |
| [2025-11-20](./changelog/work_history/2025-11-20.md) | 10-network 서브넷 이름/리전 동적 생성 |
| [2025-11-19](./changelog/work_history/2025-11-19.md) | jsj-game-n 환경 생성 및 State 관리 안정화 |
| [2025-11-18](./changelog/work_history/2025-11-18.md) | Memorystore PSC 구성 완료 |
| [전체 이력](./changelog/work_history/README.md) | 전체 작업 이력 조회 |

---

## 작업 시나리오별 참조 문서

### 시나리오 1: 신규 환경 구축

1. [사전 요구사항](./getting-started/prerequisites.md) 확인
2. [Bootstrap 구성](./getting-started/bootstrap-setup.md) 수행
3. [첫 번째 환경 배포](./getting-started/first-deployment.md) 진행

### 시나리오 2: 기존 환경 복제

1. [신규 프로젝트 추가](./guides/adding-new-project.md) 절차 수행
2. [Terragrunt 운영](./guides/terragrunt-usage.md) 가이드 참조

### 시나리오 3: 장애 발생 시

1. [일반 오류 대응](./troubleshooting/common-errors.md)에서 오류 메시지 검색
2. 해당 카테고리별 상세 문서 참조
   - State 관련: [State 관련 장애](./troubleshooting/state-issues.md)
   - 네트워크 관련: [네트워크 장애](./troubleshooting/network-issues.md)

### 시나리오 4: CI/CD 자동화 구축

1. [Jenkins CI/CD 구성](./guides/jenkins-cicd.md) 가이드 참조
2. [Terragrunt 운영](./guides/terragrunt-usage.md) 병행 검토

### 시나리오 5: 아키텍처 이해

1. [시스템 구조](./architecture/overview.md) 전체 개요 파악
2. [시스템 다이어그램](./architecture/diagrams.md) 시각 자료 확인
3. 세부 주제별 문서 참조

---

## 문서 검색 방법

### 키워드 검색

- **명령어 참조**: [명령어 참조](./getting-started/quick-commands.md)
- **오류 메시지**: [일반 오류 대응](./troubleshooting/common-errors.md)에서 Ctrl+F 검색
- **모듈 사용법**: 상단 모듈 문서 표에서 해당 모듈 선택
- **배포 순서**: [첫 번째 환경 배포](./getting-started/first-deployment.md)

### 카테고리별 접근

- **초기 구축**: [getting-started/](./getting-started/)
- **설계 문서**: [architecture/](./architecture/)
- **운영 절차**: [guides/](./guides/)
- **장애 대응**: [troubleshooting/](./troubleshooting/)

---

## 문서 버전 정보

- **최종 업데이트**: 2025-11-13
- **문서 버전**: 2.1
- **프로젝트 상태**: 운영 중

---

## 기술 지원

문서 관련 문의사항이 있을 경우:

1. 해당 카테고리 문서 확인
2. [CHANGELOG](./changelog/CHANGELOG.md) 및
   [작업 이력](./changelog/work_history/README.md) 검토
3. GitHub Issues 등록

---

## 부록

- [이전 버전 문서](./archive/) - 구버전 문서 아카이브
- [문서 재구성 요약](./REORGANIZATION_SUMMARY.md) - 2025-11-12 문서 재구성 작업 내역
