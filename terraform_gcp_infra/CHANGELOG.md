# 변경 이력

이 프로젝트의 모든 주요 변경 사항이 이 파일에 기록됩니다.

형식: [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/) 기반
버저닝: [Semantic Versioning](https://semver.org/lang/ko/) 준수

## [미배포] - 2025-11-03

### 변경 (Changed)
- `environments/prod/proj-default-templet` 전역을 Terragrunt 구조로 전환
  - 루트 및 각 레이어에 `terragrunt.hcl` 추가하고 의존 관계를 선언해 실행 순서 자동화
  - Terraform 코드에는 빈 `backend "gcs" {}` 블록만 유지하여 Terragrunt가 원격 상태를 관리하도록 조정
  - `common.naming.tfvars`와 레이어별 `terraform.tfvars`를 Terragrunt가 자동 병합하도록 구성해 `-var-file` 전달이 불필요해짐
- README/QUICK_REFERENCE/ARCHITECTURE/WORK_HISTORY 등 문서를 Terragrunt 플로우와 호환되도록 업데이트
- Terragrunt 0.92 CLI 기준 명령 예시(`terragrunt init/plan/apply`, `terragrunt state/output`)로 가이드 갱신

### 운영 (Operations)
- `/root/.bashrc`에 Terragrunt 바이너리 alias(`terragrunt='/mnt/d/jsj_wsl_data/terragrunt_linux_amd64'`)를 등록해 모든 세션에서 동일한 명령 사용
- WSL에서 Google provider가 소켓 옵션을 설정하지 못하는 이슈를 문서화하고, Linux/컨테이너 등 대안 실행 환경을 안내

## [미배포] - 2025-10-31

### 수정 (Fixed)

- **네트워크 모듈 EGRESS 지원**:
  - `modules/network-dedicated-vpc`에서 방화벽 규칙을 정규화하여 `name` 참조 오류를 수정
  - EGRESS 규칙 기본 목적지를 `0.0.0.0/0`으로 설정하고 `source_ranges`/`destination_ranges`가 자동으로 분기되도록 조정
- **project-base API 의존성 정리**:
  - `google_project_service`에 프로젝트 ID를 명시해 모듈 호출 시 안전성 향상
  - Logging 버킷/서비스 계정이 API 활성화 이후에 생성되도록 `depends_on` 추가
- **Cloud SQL 로그 플래그 중복 제거**:
  - `modules/cloudsql-mysql`이 `database_flags`에 이미 `log_output`이 있을 경우 중복으로 추가하지 않도록 수정
  - README에 동작 설명 주석 추가

### 운영 (Operations)
- 테스트 환경(jsj-game-d) 전체 `terraform destroy` 및 디렉터리 정리
- GCS 보존 설정으로 생성된 lien(`p861601542676-l299e11ad-124f-42de-92ae-198e8dd6ede6`)을 해제하여 프로젝트 삭제 완료

### 변경 (Changed)
- `proj-default-templet` 템플릿의 공통 라벨을 하이픈(`cost-center`, `managed-by`) 기준으로 통일하고 예제와 naming 입력 간 키가 일치하도록 정리
- 20-storage, 30-security, 50-workloads, 60-database, 70-loadbalancer 레이어가 `modules/naming` 기반 기본 이름과 라벨을 자동 사용하도록 정비
  - GCS 버킷/서비스 계정/Load Balancer 이름은 `terraform.tfvars`에서 생략해도 규칙에 맞춰 생성
  - VM 서브넷·서비스 계정 이메일·Private IP 네트워크가 자동 계산되도록 기본값 추가
- 공통 입력 파일 `common.naming.tfvars`를 추가하여 프로젝트/환경/조직/리전 값을 한 곳에서 관리
- Terragrunt 기반 구조로 전환을 준비했으나, 현재 WSL 환경에서 바이너리 다운로드가 차단되어 적용 보류 중

## [미배포] - 2025-10-30

### 수정 (Fixed) - 세션 7

#### proj-default-templet 템플릿 동기화
- **변수 구조 오류 수정**:
  - 00-project/variables.tf: region 변수가 project_id 블록 안에 잘못 포함되어 있던 문제 수정
  - 30-security/variables.tf: 동일한 변수 구조 오류 수정
- **20-storage 레이어 동기화**:
  - jsj-game-c에 있던 세션 7 변수들이 템플릿에 누락되어 있던 문제 수정
  - logs_enable_versioning, logs_cors_rules, backups_cors_rules 추가
  - main.tf의 하드코딩된 값들을 변수로 변경
  - terraform.tfvars에 누락된 변수 값 추가
- **결과**: proj-default-templet과 jsj-game-c의 모든 main.tf, variables.tf가 완전히 동일화됨

### 변경 (Changed) - 세션 7

#### 프로젝트 설정 가능성 개선
- **Region 변수 추가**: 모든 레이어(00-project ~ 70-loadbalancer)에 region 변수 추가
  - Provider 블록의 하드코딩된 "us-central1"을 `var.region`으로 변경
  - 모든 terraform.tfvars에 region 설정 추가
  - 기본값: "us-central1" (필요 시 변경 가능)
  - 다중 지역 배포 시 각 레이어별로 region 설정 가능

#### 하드코딩 제거
- **20-storage 레이어**: 하드코딩된 값들을 변수화
  - `logs_enable_versioning`: 로그 버킷 버전 관리 (기본값: false)
  - `logs_cors_rules`: 로그 버킷 CORS 규칙 (기본값: [])
  - `backups_cors_rules`: 백업 버킷 CORS 규칙 (기본값: [])
  - 모든 설정이 terraform.tfvars에서 관리 가능

#### terraform.tfvars 완성
- **60-database, 70-loadbalancer**: 실제 terraform.tfvars 파일 생성
  - 이전에는 .example 파일만 존재
  - 모든 레이어가 이제 실제 terraform.tfvars 포함
  - 기본 설정값으로 즉시 배포 가능
  - 프로젝트 복제 시 수정 용이

#### 문서화
- **README.md**: naming 모듈 기반 중앙 집중식 naming 섹션 추가
  - naming 모듈과 공통 입력값의 역할 설명
  - 새 프로젝트 추가 가이드 개선
  - Step-by-step 프로젝트 생성 절차
- **QUICK_REFERENCE.md**: 세션 7 작업 내용 추가
- **CHANGELOG.md**: 변경 이력 업데이트

## [미배포] - 2025-10-29

### 수정 (Fixed)

#### 프로젝트 삭제 방지 설정
- **deletion_policy 제거 및 주석 안내로 변경**:
  - `google_project` 리소스는 `deletion_policy` 속성을 지원하지 않음
  - Terraform의 `lifecycle` 블록은 변수 사용 불가 (메타-인자 제한)
  - 해결: 주석 처리된 lifecycle 블록으로 사용자가 필요 시 활성화
  - project-base 모듈의 main.tf에 주석으로 안내 추가
  - 프로덕션 환경에서는 수동으로 주석 해제하여 사용

### 추가 (Added)

#### Observability 개선
- **Cloud SQL 로깅**: MySQL 쿼리 로깅 및 Cloud Logging 통합
  - 느린 쿼리 로그 (Slow Query Log) 자동 구성
  - 일반 쿼리 로그 (General Log) 옵션
  - Cloud Logging으로 자동 전송 (FILE 출력)
  - 로깅 변수: `enable_slow_query_log`, `slow_query_log_time`, `enable_general_log`, `log_output`
  - 기본값: 느린 쿼리 로그 활성화 (2초 기준), 일반 로그 비활성화

### 추가 (Added) - 세션 5

#### 새로운 모듈
- **cloudsql-mysql**: Cloud SQL MySQL 데이터베이스 관리 모듈
  - High Availability (REGIONAL/ZONAL) 지원
  - Private IP 네트워킹
  - 자동 백업 및 Point-in-Time Recovery
  - 읽기 복제본 (Read Replica) 지원
  - Query Insights 성능 모니터링
  - 데이터베이스 및 사용자 관리
  - 데이터베이스 플래그 커스터마이징

- **load-balancer**: 다중 타입 Load Balancer 관리 모듈
  - HTTP(S) Load Balancer (글로벌, 외부)
  - Internal HTTP(S) Load Balancer (리전, 내부)
  - Internal TCP/UDP Load Balancer (리전, 내부)
  - Global 및 Regional Health Check
  - SSL/TLS 종료
  - Cloud CDN 통합
  - Identity-Aware Proxy (IAP)
  - URL 라우팅 및 호스트 규칙

#### 새로운 인프라 레이어
- **60-database**: Cloud SQL 배포 레이어
  - MySQL 데이터베이스 구성
  - Private IP 네트워킹 설정
  - 백업 및 복제본 관리

- **70-loadbalancer**: Load Balancer 배포 레이어
  - 다양한 LB 타입 지원
  - Health Check 구성
  - SSL 및 CDN 설정

#### Bootstrap 및 State 관리
- **Bootstrap 프로젝트**: 중앙 집중식 Terraform State 관리
  - 관리용 프로젝트 (`delabs-system-mgmt`)
  - 중앙 State 버킷 (`delabs-terraform-state-prod`)
  - Versioning 및 Lifecycle 정책 자동 설정
  - 모든 레이어의 backend.tf 설정

### 변경 (Changed)

#### 프로젝트 구조
- **프로젝트 템플릿화**: `proj-game-a` → `proj-default-templet`
  - 재사용 가능한 템플릿 구조로 변경
  - 레이블 정보 업데이트 (cost_center, created_by)

#### 모듈 개선
- **project-base 모듈**: `deletion_policy` 변수화
  - 기본값: `DELETE` (자유롭게 삭제 가능)
  - 옵션: `PREVENT` (삭제 방지), `ABANDON` (리소스 유지)
  - 개발/테스트 환경에서 유연한 관리 가능

### 수정 (Fixed)

#### Load Balancer 모듈 버그 수정
1. **Static IP 참조 로직**
   - `create_static_ip=true`일 때 생성된 IP 리소스 사용
   - 조건부 참조로 에러 방지

2. **Regional Health Check 지원**
   - Internal Classic LB용 `google_compute_region_health_check` 추가
   - Global/Regional Health Check 자동 선택

3. **리소스 이름 기본값**
   - URL Map, Target Proxy 이름 자동 생성
   - 빈 문자열일 때 기본값 사용

4. **SSL Policy null 처리**
   - 빈 문자열을 null로 변환하여 선택적 사용 지원

5. **IAP enabled 속성**
   - IAP 블록에 `enabled = true` 속성 추가

#### 모듈 오류 수정 (세션 2)
- **project-base**: `google_billing_project` → `google_project`에 통합
- **network-dedicated-vpc**: 중복 outputs.tf 제거
- **observability**: 중복 outputs.tf 제거

### 문서화 (Documentation)

- **ARCHITECTURE.md (신규)**: 시각적 아키텍처 다이어그램 문서
  - 10개의 Mermaid 다이어그램
  - 전체 시스템 구조, State 관리, 배포 순서
  - 모듈 구조, GCP 리소스 배치, 네트워크 흐름
  - Terraform 실행 흐름, 설계 결정, 확장 로드맵
  - 모듈 구조 다이어그램 개선 (간단명료한 레이아웃)
- **모듈 README**: cloudsql-mysql, load-balancer 한글 문서 추가
- **메인 README**: 새 모듈 및 레이어 반영, 배포 순서 업데이트
- **WORK_HISTORY**: 세션 3, 4, 5 작업 상세 기록
- **QUICK_REFERENCE**: 빠른 참조 가이드 업데이트, ARCHITECTURE.md 링크 추가
- **CHANGELOG**: 변경 이력 구조화, 마이그레이션 가이드 확장

## [세션 1-2] - 2025-10-28

### 변경 - 베스트 프랙티스 개선

#### 높은 우선순위 수정

- **모든 모듈에서 provider 블록 제거**
  - 모듈에서 더 이상 `provider` 블록을 선언하지 않음
  - 모듈에는 `required_providers`만 지정
  - Provider 구성은 루트 레벨에서만 관리
  - 모듈 재사용성 향상 및 버전 충돌 방지
  - 영향받는 모듈: gcs-root, gcs-bucket, project-base, network-dedicated-vpc, iam, observability, gce-vmset

- **IAM binding에서 member로 마이그레이션**
  - `google_storage_bucket_iam_binding`을 `google_storage_bucket_iam_member`로 변경
  - Non-authoritative 방식으로 기존 권한 덮어쓰기 방지
  - Terraform 외부에서 설정한 권한이 실수로 제거되는 위험 감소
  - 모듈: gcs-bucket

- **Notification 리소스 키 충돌 수정**
  - Notification의 for_each 키를 `topic`에서 인덱스로 변경
  - 동일한 topic에 대해 여러 notification 생성 가능
  - 모듈: gcs-bucket

#### 중간 우선순위 개선

- **15-storage를 gcs-root 모듈 사용으로 리팩토링**
  - 3개의 개별 모듈 호출을 하나의 gcs-root 사용으로 통합
  - 코드 중복 감소
  - 공통 설정 중앙화 (labels, KMS key, public access prevention)
  - 유지 관리 및 확장 용이

- **공통 naming 규칙 추가**
  - 표준화된 naming 패턴으로 `locals.tf` 생성
  - 모든 리소스에 대한 공통 label 정의
  - 일관된 리소스 prefix 설정
  - 위치: environments/prod/proj-game-a/locals.tf

- **terraform.tfvars.example 파일 생성**
  - 필수 변수에 대한 템플릿 제공
  - 유용한 주석 및 예제 포함
  - 추가 대상: 00-project, 15-storage
  - 민감한 값의 실수로 인한 커밋 방지

#### 문서화

- **포괄적인 README 파일 추가**
  - 전체 문서가 포함된 메인 프로젝트 README
  - gcs-root 및 gcs-bucket에 대한 모듈별 README
  - 사용 예제 및 베스트 프랙티스
  - Input/output 문서

- **.gitignore 생성**
  - Terraform state 파일 제외
  - *.tfvars 제외 (*.tfvars.example은 유지)
  - .terraform 디렉토리 제외
  - IDE 및 편집기 파일 포함

### 보안 개선

- Non-authoritative IAM 바인딩 강제 적용
- 공개 액세스 방지 기본값 유지
- Uniform bucket-level access 활성화 유지
- CMEK 암호화 지원 유지

### 코드 품질

- 모듈에서 provider 선언 제거
- for_each 키 고유성 개선
- 관심사 분리 개선
- 더 유지 관리하기 쉬운 코드 구조

## 마이그레이션 가이드

### 새로운 모듈 사용하기

#### 1. Cloud SQL MySQL 배포
```bash
cd environments/prod/proj-default-templet/60-database
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 편집:
# - project_id: GCP 프로젝트 ID
# - instance_name: DB 인스턴스 이름
# - tier: 머신 타입 (db-n1-standard-1 등)
# - network: Private IP용 VPC 네트워크 설정
# - databases: 생성할 데이터베이스 목록
# - users: 생성할 사용자 목록

terraform init
terraform plan
terraform apply
```

**중요 사항**:
- Private IP 사용 시 VPC peering 필요 (10-network 레이어 먼저 배포)
- 비밀번호는 terraform.tfvars에 직접 저장하지 말고 환경변수 사용 권장
- 삭제 방지: `deletion_protection = true` 설정 권장

#### 2. Load Balancer 배포
```bash
cd environments/prod/proj-default-templet/70-loadbalancer
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 편집:
# - project_id: GCP 프로젝트 ID
# - lb_type: "http", "internal", "internal_classic" 중 선택
# - backends: 백엔드 인스턴스 그룹 목록
# - health_check_port: Health Check 포트
# - use_ssl: HTTPS 사용 여부

terraform init
terraform plan
terraform apply
```

**LB 타입 선택 가이드**:
- `http`: 외부 웹 트래픽, 글로벌, SSL/CDN 지원
- `internal`: 내부 HTTP(S) 트래픽, 리전별
- `internal_classic`: 내부 TCP/UDP 트래픽, 리전별

### 기존 배포된 인프라가 있는 경우

이전 코드로 배포된 기존 인프라가 있는 경우:

1. **Provider 블록 제거** - State 변경 불필요, 루트 구성만 업데이트

2. **IAM binding에서 member로** - 주의 깊은 마이그레이션 필요:
   ```bash
   # 현재 IAM 바인딩 확인
   terraform state list | grep iam_binding

   # member로 import 필요할 수 있음
   terraform import 'module.gcs_bucket.google_storage_bucket_iam_member.members["role-member"]' ...
   ```

3. **15-storage 리팩토링** - State 마이그레이션 필요:
   ```bash
   # 개별 모듈에서 gcs-root로 state 이동
   terraform state mv 'module.game_assets_bucket' 'module.game_storage.module.gcs_buckets["assets"]'
   terraform state mv 'module.game_logs_bucket' 'module.game_storage.module.gcs_buckets["logs"]'
   terraform state mv 'module.game_backups_bucket' 'module.game_storage.module.gcs_buckets["backups"]'
   ```

### 변경 사항 테스트

프로덕션에 적용하기 전:

```bash
# 코드 포맷팅
terraform fmt -recursive

# 검증
terraform validate

# 보안 스캔
tfsec .

# 적용하지 않고 Plan만 확인
terraform plan
```

## 적용된 베스트 프랙티스

✅ 모듈 내 provider 블록 없음
✅ Non-authoritative IAM 관리
✅ 고유한 for_each 키
✅ 중앙화된 naming 규칙
✅ 예제 tfvars 파일
✅ 포괄적인 문서화 (한글)
✅ 적절한 .gitignore
✅ 보안 우선 기본값
✅ 중앙 집중식 State 관리
✅ Bootstrap 프로젝트 패턴
✅ 조건부 리소스 생성
✅ 다양한 데이터베이스 옵션 지원
✅ 다양한 Load Balancer 타입 지원

## 현재 모듈 목록 (총 9개)

1. ✅ **gcs-root**: 다중 버킷 관리
2. ✅ **gcs-bucket**: 단일 버킷 구성
3. ✅ **project-base**: GCP 프로젝트 생성
4. ✅ **network-dedicated-vpc**: VPC 네트워킹
5. ✅ **iam**: IAM 관리
6. ✅ **observability**: 모니터링 및 로깅
7. ✅ **gce-vmset**: VM 인스턴스
8. ✅ **cloudsql-mysql**: Cloud SQL MySQL
9. ✅ **load-balancer**: Load Balancer

## 향후 개선 사항

### 새로운 모듈 추가
- [ ] **cloudsql-postgresql**: PostgreSQL 데이터베이스 모듈
- [ ] **cloud-memorystore**: Redis/Memcached 모듈
- [ ] **gke-cluster**: Google Kubernetes Engine 모듈
- [ ] **cloud-functions**: Cloud Functions 모듈
- [ ] **cloud-run**: Cloud Run 서비스 모듈
- [ ] **firestore**: Firestore 데이터베이스 모듈
- [ ] **pubsub**: Pub/Sub 토픽 및 구독 모듈
- [ ] **cloud-armor**: 보안 정책 모듈
- [ ] **secret-manager**: Secret Manager 모듈

### 인프라 개선
- [ ] dev 및 staging 환경 추가
- [ ] CI/CD에 tfsec 구현
- [ ] 포맷팅을 위한 pre-commit hook 추가
- [ ] terraform-docs 자동화 추가
- [ ] OPA/Sentinel을 사용한 policy-as-code 구현
- [ ] 자동화된 모니터링 대시보드 생성
- [ ] Cost optimization 가이드 추가

### 문서화
- [ ] 아키텍처 다이어그램 추가
- [ ] 실제 사용 사례 (Use Cases) 문서
- [ ] 트러블슈팅 가이드 확장
- [ ] 성능 튜닝 가이드
