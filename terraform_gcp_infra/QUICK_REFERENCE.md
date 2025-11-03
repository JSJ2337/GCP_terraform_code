# 빠른 참조 가이드

## 🚀 다음 세션 시작 시

```bash
# 1. WORK_HISTORY.md 읽기
cat WORK_HISTORY.md

# 2. 코드 포맷팅 및 검증 (완료됨)
terraform fmt -recursive

# 3. 각 레이어 검증 (완료됨)
# 모든 모듈이 validate 통과

# 4. Plan 확인 (실제 프로젝트가 있다면)
cd environments/prod/proj-default-templet/00-project
terraform plan
```

## 📝 변경된 파일 요약

### 세션 1: 초기 베스트 프랙티스 적용 (11개 수정, 9개 신규)
- 모듈 7개: provider 블록 제거
- 15-storage 3개: gcs-root 사용으로 리팩토링
- locals.tf: 공통 naming
- *.tfvars.example: 설정 예제
- README.md, CHANGELOG.md, .gitignore

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
  - README.md, WORK_HISTORY.md 업데이트

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
  - README.md에 locals.tf 중앙 집중식 naming 섹션 추가
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
- **라벨 통일**:
  - proj-default-templet locals/tfvars 예제를 하이픈 키(`managed-by`, `cost-center`)로 정리
- **운영 작업**:
  - 테스트 환경(jsj-game-d) 전면 제거 및 디렉터리 정리
  - Storage retention lien 제거 후 프로젝트 삭제 완료

## ⚠️ 주의: State 마이그레이션 필요

기존 인프라가 있다면:

```bash
# 15-storage 리팩토링
terraform state mv 'module.game_assets_bucket' 'module.game_storage.module.gcs_buckets["assets"]'
terraform state mv 'module.game_logs_bucket' 'module.game_storage.module.gcs_buckets["logs"]'
terraform state mv 'module.game_backups_bucket' 'module.game_storage.module.gcs_buckets["backups"]'

# IAM 변경 시 (binding → member)
# WORK_HISTORY.md의 트러블슈팅 섹션 참조
```

## 🎯 핵심 변경 내용

### 완료됨 ✅
1. ✅ Provider 블록 제거 → 모듈 재사용성 ↑
2. ✅ IAM binding → member → 충돌 방지
3. ✅ 15-storage gcs-root 사용 → 코드 간소화
4. ✅ locals.tf 추가 → naming 일관성
5. ✅ 모듈 오류 수정 (project-base, network-dedicated-vpc, observability)
6. ✅ 코드 포맷팅 (terraform fmt)
7. ✅ 모든 모듈 검증 완료
8. ✅ 레이어에 locals 적용 (00-project, 10-network, 40-workloads)
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
21. ✅ 중앙 집중식 Naming 문서화 (locals.tf 사용법)

## 📂 중요 파일

| 파일 | 용도 |
|------|------|
| ARCHITECTURE.md | 시각적 아키텍처 다이어그램 10개 (⭐ 신규, 개선됨) |
| WORK_HISTORY.md | 전체 작업 내역 상세 |
| CHANGELOG.md | 변경 이력 + 마이그레이션 가이드 |
| README.md | 프로젝트 전체 가이드 |
| QUICK_REFERENCE.md | 빠른 참조 가이드 (이 문서) |
| locals.tf | 공통 naming/labeling |

## 🔧 자주 사용하는 명령어

```bash
# 포맷팅
terraform fmt -recursive

# 검증
terraform validate

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# State 확인
terraform state list

# Output 확인
terraform output -json | jq

# 데이터베이스 배포
cd environments/prod/proj-default-templet/60-database
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정 후
terraform init && terraform plan && terraform apply

# 로드 밸런서 배포
cd ../70-loadbalancer
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정 후
terraform init && terraform plan && terraform apply
```

## 📞 문제 해결

- **Plan에서 리소스 재생성 감지**: WORK_HISTORY.md "증상 1" 참조
- **Bucket 재생성 시도**: WORK_HISTORY.md "증상 2" 참조
- **Provider 오류**: WORK_HISTORY.md "증상 3" 참조

## ⏭️ 다음 작업 (우선순위)

### 즉시 작업 가능
1. [ ] 60-database 레이어 배포 (Cloud SQL MySQL)
   - terraform.tfvars 작성 (프로젝트 ID, 네트워크 설정)
   - Private IP 설정 확인
   - 백업 정책 설정
2. [ ] 70-loadbalancer 레이어 배포 (Load Balancer)
   - LB 타입 선택 (HTTP(S), Internal, Internal Classic)
   - 백엔드 인스턴스 그룹 설정
   - Health Check 설정
3. [ ] tfsec 보안 스캔 (새 모듈 포함)
4. [ ] 실제 프로젝트에 배포 (terraform plan/apply)
5. [ ] State 마이그레이션 (기존 인프라가 있다면)

### 향후 개선 사항
6. [ ] PostgreSQL 모듈 추가 (cloudsql-postgresql)
7. [ ] Redis/Memorystore 모듈 추가
8. [ ] GKE (Kubernetes) 모듈 추가
9. [ ] Dev/Staging 환경 추가
10. [ ] CI/CD 파이프라인 구축 (GitHub Actions)
11. [ ] Pre-commit hooks 설정
12. [ ] Cost estimation (infracost)
13. [ ] Monitoring 대시보드 자동 생성

---

**상세 내용**: WORK_HISTORY.md 참조
