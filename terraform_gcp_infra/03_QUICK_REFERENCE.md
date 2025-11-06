# 빠른 참조 가이드

## 🚀 다음 세션 시작 시

```bash
# 1. 04_WORK_HISTORY.md 읽기
cat 04_WORK_HISTORY.md

# 2. 코드 포맷팅 (필요 시)
terraform fmt -recursive

# 3. Terragrunt 플랜 (예: jsj-game-g 환경)
cd environments/LIVE/jsj-game-g/00-project
terragrunt init --non-interactive
terragrunt plan
```

## 📝 변경된 파일 요약

### 세션 13: Bootstrap Service Account 및 GCP 인증 설정 (2025-11-06)
- **Bootstrap Service Account 자동 생성**:
  - `jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com` Terraform으로 생성
  - Infrastructure as Code로 관리 (bootstrap/main.tf)
  - 조직 레벨 권한 부여 로직 추가 (조직 있는 경우)
- **Service Account 필수 권한 설정**:
  - `delabs-system-mgmt`: `roles/storage.admin` (State 버킷 접근)
  - `jsj-game-g`: `roles/editor` (리소스 관리)
  - 조직 없는 환경에서 프로젝트별 권한 수동 부여 방식
- **조직 없는 환경 대응**:
  - 프로젝트 수동 생성 방식 문서화 및 실행
  - jsj-game-g 프로젝트 생성 (Project Number: 865467708587)
  - Billing account 수동 연결
- **Jenkins GCP 인증 통합**:
  - Jenkinsfile에 `GOOGLE_APPLICATION_CREDENTIALS` 환경변수 추가
  - Credential ID: `gcp-jenkins-service-account`
  - Secret file 타입으로 Service Account Key 관리
- **Jenkinsfile Working Directory 수정**:
  - `TG_WORKING_DIR`을 workspace root 기준 절대 경로로 변경
  - 예: `terraform_gcp_infra/environments/LIVE/jsj-game-g`
  - 템플릿 디렉터리와의 충돌 방지
- **terragrunt.hcl 설정 개선**:
  - GCS remote_state에 `project`, `location` 파라미터 필수 추가
  - `terraform.source` 블록 제거하여 in-place 실행
  - `.terragrunt-cache` 사용 안 함으로 모듈 경로 문제 해결
  - 18개 레이어 파일 업데이트 (jsj-game-g 9개 + proj-default-templet 9개)
- **에러 해결**:
  - "storage.buckets.create access denied" → Storage Admin 권한 부여로 해결
  - "Missing required GCS remote state configuration" → project/location 추가로 해결
  - "Unreadable module directory" → terraform.source 제거로 해결
- **문서 업데이트**:
  - 00_README.md: GCP 인증 설정 섹션 대폭 수정 (Bootstrap 통합, 조직 없는 환경 대응)
  - 02_CHANGELOG.md: 2025-11-06 변경사항 추가
  - 05_quick setup guide.md: terragrunt.hcl 필수 설정, Jenkinsfile 설정 가이드 추가
  - bootstrap/README.md: Service Account 권한 설정 추가
  - 03_QUICK_REFERENCE.md: 세션 13 기록
- **추가 후속 정리** (2025-11-06 오후):
  - Terragrunt가 `region_primary`를 기본 적용하도록 모든 tfvars/example/README에서 `region = ""` 패턴 삭제
  - `modules/gcs-bucket`이 `public_access_prevention`·`retention_policy_days`가 `null`일 때도 안전하게 동작하도록 validation/동적 블록 보완
  - Bootstrap이 `cloudbilling.googleapis.com`, `serviceusage.googleapis.com`을 자동 활성화하여 신규 프로젝트 생성 시 Billing/API 오류 예방
  - Jenkins 서비스 계정 필수 권한/Billing API 체크리스트를 README·Jenkins 문서에 명시 (billing.user 미설정으로 인한 apply 실패 방지)

### 세션 12: Jenkins CI/CD 통합 및 프로젝트 재구성 (2025-11-05)
- **디렉터리 구조 재정리**:
  - `proj-default-templet`을 `terraform_gcp_infra/` 루트로 이동 (템플릿과 실제 환경 분리)
  - `environments/LIVE/jsj-game-g` 첫 번째 실제 배포 환경 생성 (Project ID: jsj-game-g, Region: asia-northeast3)
- **환경별 Jenkinsfile 구조**:
  - `Jenkinsfile`을 `environments/LIVE/jsj-game-g/`로 이동 (각 환경이 독립적인 Pipeline 보유)
  - `.jenkins/Jenkinsfile.template` 생성 (재사용 가능한 템플릿)
  - `TG_WORKING_DIR`을 절대 경로로 설정 (workspace root 기준)
  - Script Path: `environments/LIVE/{project}/Jenkinsfile`
- **Jenkins Docker 설정**:
  - Jenkins LTS + Terraform 1.9.8 + Terragrunt 0.68.15 + Git 사전 설치
  - GitHub Webhook 자동 빌드 연동
  - ngrok을 통한 외부 접속 지원
- **Terragrunt CI/CD Pipeline**:
  - 승인 단계가 있는 안전한 배포 Pipeline (30분 타임아웃, admin 전용)
  - Plan/Apply/Destroy 파라미터 선택
  - 전체 스택 또는 개별 레이어 실행
- **중앙 관리 Service Account**:
  - `delabs-system-mgmt` 프로젝트에서 `jenkins-terraform-admin` SA 생성
  - 하나의 Key로 모든 프로젝트 관리 (Key 관리 포인트 최소화)
- **문서 업데이트**:
  - 00_README.md: 새 구조, Jenkins CI/CD 섹션 추가
  - 03_QUICK_REFERENCE.md: 최신 세션 기록, 경로 업데이트
  - 05_quick setup guide.md: 템플릿 경로 수정
  - 02_CHANGELOG.md: 프로젝트 재구성 및 Jenkins 통합 기록

### 세션 10: Private Service Connect 및 템플릿 변수 예시 (2025-11-04)
- 10-network 템플릿에 Private Service Connect 예약 리소스(`google_service_networking_connection`) 추가 및 tfvars 토글 제공
- 30-security 템플릿이 naming 모듈 출력으로 기본 서비스 계정을 자동 생성하도록 개선
- 모든 레이어에 한글 `terraform.tfvars.example` 배포 (신규 4개, 갱신 4개) → 복사 후 값만 수정하면 바로 실행 가능
- 00_README / 01_ARCHITECTURE / 02_CHANGELOG / 04_WORK_HISTORY / 03_QUICK_REFERENCE 문서에 새 흐름과 주의사항 반영
- jsj-game-e 환경 destroy 재시도 → Service Networking 연결 해제 후 완전 삭제 완료

### 세션 11: Memorystore Redis 템플릿 추가 (2025-11-04)
- `modules/memorystore-redis` 모듈 신설 (STANDARD_HA 구성을 기본값으로 제공)
- `environments/LIVE/proj-default-templet/65-cache` Terragrunt 레이어 추가 및 예시 tfvars/README 작성
- `modules/naming`에 `redis_instance_name` 출력 추가로 캐시 네이밍 일관성 확보
- `modules/observability` 기본 Alert 템플릿을 확장하고 40-observability 레이어가 GCE/Cloud SQL/Memorystore/HTTPS LB 경보를 자동 배포하도록 갱신
- 01_ARCHITECTURE / 03_QUICK_REFERENCE / 02_CHANGELOG 문서를 Redis/Monitoring 흐름을 포함하도록 갱신

### 세션 1: 초기 베스트 프랙티스 적용 (11개 수정, 9개 신규)
- 모듈 7개: provider 블록 제거
- 15-storage 3개: gcs-root 사용으로 리팩토링
- locals.tf: 공통 naming
- *.tfvars.example: 설정 예제
- 00_README.md, 02_CHANGELOG.md, .gitignore

### 세션 2: 오류 수정 및 문서화 (3개 수정, 5개 신규)
- **오류 수정 (3개)**:
  - project-base: `google_billing_project` → `google_project`에 통합
  - network-dedicated-vpc: 중복 outputs.tf 제거
  - observability: 중복 outputs.tf 제거
- **Locals 적용 (4개)**:
  - 00-project: common_labels 적용
  - 10-network: naming convention 적용
  - 40-workloads: VM naming convention 적용
  - (15-storage는 이미 적용됨)
- **README 작성 (5개)**:
  - project-base/README.md
  - network-dedicated-vpc/README.md
  - iam/README.md
  - observability/README.md
  - gce-vmset/README.md

### 세션 3: Bootstrap 및 중앙 State 관리 구현
- Bootstrap 프로젝트 생성 (중앙 State 관리)
- 모든 레이어의 backend.tf 설정
- 문서화 업데이트

### 세션 4: 프로젝트 삭제 정책 및 템플릿화
- JSJ-game-terraform-A 프로젝트 삭제
- deletion_policy 변수 추가
- proj-game-a → proj-default-templet 템플릿화
- locals.tf 레이블 업데이트

### 세션 5: Cloud SQL 및 Load Balancer 모듈 추가 (18개 신규)
- **새 모듈 (8개 파일)**:
  - cloudsql-mysql: MySQL 데이터베이스 관리
  - load-balancer: HTTP(S)/Internal LB 관리
- **새 레이어 (10개 파일)**:
  - 60-database: Cloud SQL 배포
  - 70-loadbalancer: Load Balancer 배포
- **버그 수정 (5건)**:
  - Static IP 참조, Regional Health Check, 이름 기본값, SSL Policy, IAP enabled
- **문서화**:
  - 00_README.md, 04_WORK_HISTORY.md 업데이트

### 세션 6: Cloud SQL 로깅 기능 추가 및 버그 수정
- **Observability 개선**:
  - Cloud SQL 느린 쿼리 로깅 (기본 2초)
  - 일반 쿼리 로깅 옵션 (디버깅용)
  - Cloud Logging 자동 통합
  - 로깅 변수 4개 추가
- **문서 업데이트**:
  - cloudsql-mysql README에 로깅 섹션 추가
  - 60-database 레이어 로깅 변수 추가
- **버그 수정** (2단계):
  - 1차: deletion_policy → prevent_destroy 변경 시도
  - 2차: lifecycle 메타-인자는 변수 사용 불가 (Terraform 제한)
  - 최종: prevent_destroy 제거, 주석 안내로 변경

### 세션 7: 프로젝트 리뷰 및 변수화 개선
- **Region 변수 추가**:
  - 모든 레이어(00-project ~ 70-loadbalancer)에 region 변수 추가
  - Provider 블록의 하드코딩된 "us-central1"을 var.region으로 변경
  - terraform.tfvars에 region 설정 추가
- **하드코딩 제거**:
  - 20-storage: enable_versioning, cors_rules 변수화
  - 모든 설정값이 terraform.tfvars에서 관리 가능
- **terraform.tfvars 완성**:
  - 60-database, 70-loadbalancer에 실제 terraform.tfvars 파일 생성
  - 모든 레이어가 이제 terraform.tfvars 포함 (.example만 아님)
- **프로젝트 정리**:
  - jsj-game-b 프로젝트 검토 및 locals.tf 중복 제거
  - proj-default-templet을 기준으로 명명 규칙 통일
- **템플릿 동기화**:
  - proj-default-templet과 jsj-game-c 완전 동기화
  - 변수 구조 오류 수정 (00-project, 30-security)
  - 20-storage 누락 변수 추가 및 하드코딩 제거
- **문서화**:
  - 00_README.md에 locals.tf 중앙 집중식 naming 섹션 추가
  - 새 프로젝트 추가 가이드 개선

### 세션 8: 네트워크/DB 모듈 안정화 및 환경 정리
- **네트워크 모듈**:
  - 방화벽 규칙 입력 정규화, `name = each.key` 수정
  - EGRESS 기본 목적지를 `0.0.0.0/0`으로 설정
  - README에 EGRESS 동작 문서화
- **Cloud SQL 모듈**:
  - `log_output` 중복 추가를 방지하도록 로직 개선
  - README에 동작 설명 주석 추가
- **project-base 모듈**:
  - 필수 API 활성화 후 로깅 버킷·서비스 계정이 생성되도록 `depends_on` 추가
  - `google_project_service`에 project ID 명시
- **modules/naming 자동화**:
  - Storage/보안/워크로드/Database/Load Balancer 레이어가 naming 모듈 기반 기본 이름을 자동 사용 (tfvars에서 이름 생략 가능)
- **라벨 통일**:
  - proj-default-templet locals/tfvars 예제를 하이픈 키(`managed-by`, `cost-center`)로 정리
- **운영 작업**:
  - 테스트 환경(jsj-game-d) 전면 제거 및 디렉터리 정리
  - Storage retention lien 제거 후 프로젝트 삭제 완료

### 세션 9: Terragrunt 기반 실행 전환 (2025-11-03)
- **구조 변경**:
  - `environments/prod/proj-default-templet` 루트 및 모든 레이어에 `terragrunt.hcl` 도입
  - 빈 `backend "gcs" {}` 블록만 남기고 기존 `backend.tf` 파일 제거
  - Terragrunt가 `common.naming.tfvars`와 각 레이어의 `terraform.tfvars`를 자동 병합하도록 구성
- **자동화**:
  - 의존성(`dependencies`)으로 레이어 순서를 선언하여 상위 레이어 완료 후 실행 보장
  - Terragrunt 0.92 CLI에 맞춰 `terragrunt init/plan/apply` 커맨드 가이드 추가
  - `/root/.bashrc`에 `terragrunt` alias (`/mnt/d/jsj_wsl_data/terragrunt_linux_amd64`) 등록
- **문서 업데이트**:
  - README, QUICK_REFERENCE, CHANGELOG, WORK_HISTORY 등 전반을 Terragrunt 흐름으로 갱신
  - WSL 환경에서 provider 소켓 오류가 발생할 수 있어 대체 실행 환경을 안내

## ⚠️ 주의: State 마이그레이션 필요

기존 인프라가 있다면:

```bash
# 15-storage 리팩토링
terragrunt state mv 'module.game_assets_bucket' 'module.game_storage.module.gcs_buckets["assets"]'
terragrunt state mv 'module.game_logs_bucket' 'module.game_storage.module.gcs_buckets["logs"]'
terragrunt state mv 'module.game_backups_bucket' 'module.game_storage.module.gcs_buckets["backups"]'

# IAM 변경 시 (binding → member)
# 04_WORK_HISTORY.md의 트러블슈팅 섹션 참조
```

## 🎯 핵심 변경 내용

### 완료됨 ✅
1. ✅ Provider 블록 제거 → 모듈 재사용성 ↑
2. ✅ IAM binding → member → 충돌 방지
3. ✅ 15-storage gcs-root 사용 → 코드 간소화
4. ✅ modules/naming 도입 → naming 일관성
5. ✅ 모듈 오류 수정 (project-base, network-dedicated-vpc, observability)
6. ✅ 코드 포맷팅 (terraform fmt)
7. ✅ 모든 모듈 검증 완료
8. ✅ 레이어에 naming 모듈 연동 (00-project, 10-network, 40-workloads)
9. ✅ 모듈 README 문서 작성 (7개 → 9개로 증가)
10. ✅ Bootstrap 및 중앙 State 관리 구현
11. ✅ deletion_policy 변수화
12. ✅ 프로젝트 템플릿화 (proj-default-templet)
13. ✅ Cloud SQL MySQL 모듈 추가
14. ✅ Load Balancer 모듈 추가 (3가지 타입 지원)
15. ✅ 데이터베이스 레이어 추가 (60-database)
16. ✅ 로드 밸런서 레이어 추가 (70-loadbalancer)
17. ✅ Cloud SQL 로깅 기능 추가 (느린 쿼리 로그, Cloud Logging 통합)
18. ✅ 모든 레이어에 region 변수 추가 (완전한 지역 설정 가능)
19. ✅ 하드코딩 제거 (20-storage enable_versioning, cors_rules)
20. ✅ 모든 레이어에 terraform.tfvars 생성 (60-database, 70-loadbalancer 포함)
21. ✅ 중앙 집중식 Naming 문서화 (modules/naming 사용법)
22. ✅ Terragrunt 기반 실행으로 전환 (공통 입력/원격 상태 자동화)
23. ✅ Memorystore Redis 모듈 추가 (modules/memorystore-redis)
24. ✅ Redis 캐시 Terragrunt 레이어 추가 (65-cache)

## 📂 중요 파일

| 파일 | 용도 |
|------|------|
| 01_ARCHITECTURE.md | 시각적 아키텍처 다이어그램 10개 (⭐ 신규, 개선됨) |
| 04_WORK_HISTORY.md | 전체 작업 내역 상세 |
| 02_CHANGELOG.md | 변경 이력 + 마이그레이션 가이드 |
| 00_README.md | 프로젝트 전체 가이드 |
| 03_QUICK_REFERENCE.md | 빠른 참조 가이드 (이 문서) |
| modules/naming | 공통 naming/labeling |

## 🔧 자주 사용하는 명령어

```bash
# 포맷팅
terraform fmt -recursive

# Terragrunt 실행 (예: jsj-game-g)
cd environments/LIVE/jsj-game-g/00-project
terragrunt init --non-interactive
terragrunt plan
terragrunt apply
# ~/.bashrc에 alias terragrunt='/mnt/d/jsj_wsl_data/terragrunt_linux_amd64' 등록됨

# State / Output
terragrunt state list
terragrunt output -json | jq

# 전체 레이어 일괄 실행
./run_terragrunt_stack.sh plan --terragrunt-non-interactive
# 예: apply/destroy 시 추가 플래그 전달 가능
./run_terragrunt_stack.sh destroy --terragrunt-non-interactive -auto-approve


# 데이터베이스 배포 (60-database)
cd ../60-database
cp terraform.tfvars.example terraform.tfvars  # 최초 1회
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 캐시 배포 (65-cache)
cd ../65-cache
cp terraform.tfvars.example terraform.tfvars  # 최초 1회
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# 로드 밸런서 배포 (70-loadbalancer)
cd ../70-loadbalancer
cp terraform.tfvars.example terraform.tfvars  # 최초 1회
terragrunt init --non-interactive
terragrunt plan
terragrunt apply

# Bootstrap 프로젝트는 여전히 순수 Terraform
cd ../../../../bootstrap
terraform init && terraform apply
```

## 📞 문제 해결

- **Plan에서 리소스 재생성 감지**: 04_WORK_HISTORY.md "증상 1" 참조
- **Bucket 재생성 시도**: 04_WORK_HISTORY.md "증상 2" 참조
- **Provider 오류**: 04_WORK_HISTORY.md "증상 3" 참조
- **WSL setsockopt 오류**: 00_README.md "Terragrunt 기반 실행" 섹션 참고 (Linux/컨테이너 권장)

## ⏭️ 다음 작업 (우선순위)

### 즉시 작업 가능
1. [ ] 60-database 레이어 배포 (Cloud SQL MySQL)
   - terraform.tfvars 작성 (프로젝트 ID, 네트워크 설정)
   - Private IP 설정 확인
   - 백업 정책 설정
2. [ ] 65-cache 레이어 배포 (Memorystore Redis)
   - alternative_location_id 등 존 설정 확인
   - 메모리 용량과 Redis 버전 검토
   - Authorized network가 템플릿 VPC인지 확인
3. [ ] 70-loadbalancer 레이어 배포 (Load Balancer)
   - LB 타입 선택 (HTTP(S), Internal, Internal Classic)
   - 백엔드 인스턴스 그룹 설정
   - Health Check 설정
4. [ ] tfsec 보안 스캔 (새 모듈 포함)
5. [ ] 실제 프로젝트에 배포 (terragrunt plan/apply)
6. [ ] State 마이그레이션 (기존 인프라가 있다면)

### 향후 개선 사항
6. [ ] PostgreSQL 모듈 추가 (cloudsql-postgresql)
7. [ ] GKE (Kubernetes) 모듈 추가
8. [ ] Dev/Staging 환경 추가
9. [ ] CI/CD 파이프라인 구축 (GitHub Actions)
10. [ ] Pre-commit hooks 설정
11. [ ] Cost estimation (infracost)
12. [ ] Monitoring 대시보드 자동 생성
13. [ ] Terragrunt stack 실행 자동화(스크립트/CI) 및 WSL 대안 환경 마련

---

**상세 내용**: 04_WORK_HISTORY.md 참조
