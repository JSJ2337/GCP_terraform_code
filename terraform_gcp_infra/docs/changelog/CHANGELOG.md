# 변경 이력

이 프로젝트의 모든 주요 변경 사항이 이 파일에 기록됩니다.

형식: [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/) 기반
버저닝: [Semantic Versioning](https://semver.org/lang/ko/) 준수

<!-- markdownlint-disable MD005 MD007 MD013 MD024 -->

## [미배포] - 2025-12-10

### 추가 (Added)

- **Bastion 호스트용 Service Account 및 DNS Reader 권한**
  - `bastion-host@delabs-gcp-mgmt.iam.gserviceaccount.com` 서비스 계정 생성
  - `roles/dns.reader`: Cloud DNS 레코드 자동 조회 권한
  - `roles/compute.viewer`: VM 정보 조회 권한
  - 파일: `bootstrap/00-foundation/main.tf`, `outputs.tf`

- **66-psc-endpoints 레이어 배포 (Cross-Project PSC)**
  - Management VPC에서 각 프로젝트 Redis Cluster로 PSC Endpoint 생성
  - gcby: `10.250.20.101`, `10.250.20.102` (us-west1)
  - web3: `10.250.20.111`, `10.250.20.112` (us-west1)
  - PSC 연결 상태: `ACCEPTED` (정상)
  - 파일: `gcp-gcby/66-psc-endpoints/`, `gcp-web3/66-psc-endpoints/`

- **ssh_vm.sh 스크립트 고도화**
  - **Cloud DNS API 자동 탐색**: `gcloud dns record-sets list`로 모든 A 레코드 자동 조회
  - **Redis Cluster 지원**: redis-cli로 TLS 연결 (`--tls --insecure`)
  - **Database 제외**: PSC Endpoint는 목록에서 자동 제외
  - **redis-cli 경로 자동 감지**: PATH, /usr/local/bin, ~/redis-7.2.6/src 순서로 탐색
  - **Fallback 메커니즘**: Cloud DNS API 실패 시 dig/nslookup + 패턴 기반 조회
  - **서버 역할 자동 분류**: game, web, api, database, redis-cluster 등
  - 배포 위치: `delabs-bastion:/home/delabs-adm/ssh_vm.sh`

### 수정 (Fixed)

- **allow_stopping_for_update 추가**
  - Bastion VM에 Service Account 변경 시 자동 중지 허용
  - 파일: `bootstrap/50-compute/main.tf`
  - 에러 해결: "Changing service_account requires stopping instance"

- **Redis TLS 암호화 지원**
  - 문제: GCP Memorystore Redis Cluster는 `TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION` 사용
  - 해결: redis-cli에 `--tls --insecure` 옵션 추가
  - 테스트 결과: gcby, web3 Redis 모두 `PONG` 응답 성공

- **10-network 방화벽 규칙 수정**
  - 기존: gcp-gcby VPC에만 추가 시도 (잘못된 접근)
  - 수정: Management VPC 내부 통신은 기본 `default-allow-internal` 사용
  - PSC 연결은 66-psc-endpoints에서 처리

### 개선 (Improved)

- **ssh_vm.sh 서버 감지 자동화**
  - 하드코딩된 패턴 불필요 (Fallback용으로만 유지)
  - 새 서버 추가 시 DNS에만 등록하면 자동 인식
  - 유지보수 부담 최소화

- **Bastion 인스턴스 Service Account 연결**
  - 기본 Compute Engine SA → 전용 `bastion-host` SA 변경
  - Cloud DNS API 인증 자동화
  - 파일: `bootstrap/50-compute/layer.hcl`

### 문서화 (Documentation)

- 2025-12-10: Bastion SA, PSC Endpoints, Redis TLS, ssh_vm.sh 고도화 전체 과정 기록

---

## [미배포] - 2025-12-04

### 수정 (Fixed)

- **50-workloads network_ip 주입 문제 해결**
  - 문제: VM Static IP가 `(known after apply)`로 표시되어 설정값 적용 안됨
  - 원인1: terragrunt.hcl에서 `instances_with_network_ip` local 정의 누락
  - 원인2: terraform.tfvars 자동 로드와 terragrunt inputs 충돌
  - 해결: local 재정의 + terraform.tfvars → workloads.tfvars 파일명 변경
  - 파일: `environments/LIVE/gcp-gcby/50-workloads/terragrunt.hcl`, `workloads.tfvars`
  - 커밋: 9d8bb51

- **12-dns vm_static_ips 참조 수정**
  - 문제: `network_config.vm_ips` 속성 없음 에러
  - 원인: common.naming.tfvars에서 중복 vm_ips 제거 후 참조 누락
  - 해결: `vm_static_ips` 최상위 레벨 변수 사용
  - 파일: `environments/LIVE/gcp-gcby/12-dns/terragrunt.hcl`
  - 커밋: ae1a845

### 개선 (Improved)

- **gcp-gcby 환경 하드코딩 제거**
  - root.hcl: 환경변수 지원 (TG_STATE_BUCKET, TG_ORG_ID 등)
  - 10-network: PSC IP 기본값 제거 (common.naming.tfvars에서 주입)
  - 50-workloads: VM 이름 동적화 (`${project_name}-${key}` 패턴)
  - 파일: `root.hcl`, `10-network/variables.tf`, `50-workloads/`
  - 커밋: 363ee19

- **common.naming.tfvars 중복 설정 정리**
  - `network_config.vm_ips` 제거 (중복)
  - `vm_static_ips` 최상위 레벨만 사용
  - 파일: `environments/LIVE/gcp-gcby/common.naming.tfvars`
  - 커밋: 112ca7a

### 문서화 (Documentation)

- **Work History 추가**
  - 2025-12-04.md: 하드코딩 제거, network_ip 문제 해결 전체 과정 기록
  - 파일: `docs/changelog/work_history/2025-12-04.md`

---

## [미배포] - 2025-12-01

### 추가 (Added)

- **DNS Peering 설정 (mgmt ↔ gcby)**
  - mgmt VPC와 gcby VPC 간 양방향 VPC Peering 구성
  - mgmt VPC DNS Zone에 gcby VM DNS 레코드 추가 (gcby-gs01, gcby-gs02)
  - gcby/12-dns: DNS Peering Zone 생성 (delabsgames.internal.)
  - jenkins, bastion에서 gcby VM으로 DNS 이름 기반 접근 가능
  - 파일: `bootstrap/10-network/main.tf`, `bootstrap/12-dns/layer.hcl`, `environments/LIVE/gcp-gcby/10-network/main.tf`, `environments/LIVE/gcp-gcby/12-dns/terraform.tfvars`
  - 커밋: a74b413

- **mgmt VPC SSH 접근 방화벽 규칙**
  - allow-ssh-from-mgmt 규칙 추가 (10.250.10.0/24 → gcby VM)
  - SSH 태그 분리: ssh-from-iap (IAP), ssh-from-mgmt (mgmt VPC)
  - 50-workloads VM 태그 업데이트
  - 파일: `environments/LIVE/gcp-gcby/10-network/terraform.tfvars`, `environments/LIVE/gcp-gcby/50-workloads/terraform.tfvars`
  - 커밋: a74b413

- **Cloud SQL PSC Endpoint 지원 (3-tier 격리)**
  - 10-network: Cloud SQL Service Connection Policy 리소스 추가
    - service_class: gcp-cloud-sql
    - Private subnet에만 Endpoint 생성
    - DMZ zone에서 Cloud SQL 접근 차단 (네트워크 레벨 격리)
  - modules/cloudsql-mysql: enable_psc 변수 추가
    - PSC Endpoint 방식과 VPC Peering 방식 선택 가능
    - psc_enabled 설정, private_network 조건부 처리
  - 60-database: enable_psc = true 설정
  - 파일: `environments/LIVE/gcp-gcby/10-network/`, `modules/cloudsql-mysql/`, `environments/LIVE/gcp-gcby/60-database/`
  - 커밋: 6463e4c

### 수정 (Fixed)

- **DNS Layer 번호 변경 (75-dns → 12-dns)**
  - 문제: DNS Layer가 Phase 8에 위치 (논리적으로 Network 다음이어야 함)
  - 해결: 모든 프로젝트의 75-dns를 12-dns로 변경
    - gcp-gcby/12-dns
    - jsj-game-n/12-dns
    - proj-default-templet/12-dns
  - Jenkinsfile Phase 재편성
    - Phase 3: 12-dns (DNS Peering)
    - Phase 4-8: 기존 Phase 3-7 재배치
  - README 및 모든 문서 일괄 업데이트
  - 파일: 전체 프로젝트
  - 커밋: 여러 커밋 (force push)

- **DB subnet → PSC 전용 대역 전환**
  - 문제: DB subnet (10.10.12.0/24)과 PSC 대역이 분리됨
  - 해결: DB subnet 제거, 동일 대역을 PSC 전용으로 사용
  - modules/network-dedicated-vpc: private_service_connection_address 변수 추가
  - gcby/10-network: PSC 주소 명시적 지정 (10.10.12.0/24)
  - DB 관련 방화벽 규칙 삭제 (allow-db-internal, allow-private-to-db)
  - 파일: `modules/network-dedicated-vpc/`, `environments/LIVE/gcp-gcby/10-network/terraform.tfvars`
  - 커밋: 1c18375

### 개선 (Improved)

- **3-tier 네트워크 격리 아키텍처**
  - Before (VPC Peering): 전체 VPC에서 Cloud SQL 접근 가능 (보안 취약)
  - After (PSC Endpoint): Private subnet만 Cloud SQL 접근 가능
  - DMZ zone에서 DB 직접 접근 차단 (네트워크 레벨 격리)
  - 방화벽 우회 불가능 (PSC Endpoint는 지정된 subnet에만 생성)
  - 커밋: 6463e4c

### 보안 (Security)

- **SSH 접근 제어 강화**
  - IAP 접근과 mgmt VPC 접근을 별도 태그로 분리
  - ssh-from-iap: IAP tunnel 접근 (35.235.240.0/20)
  - ssh-from-mgmt: mgmt VPC 직접 접근 (10.250.10.0/24)
  - VM별로 선택적 SSH 접근 제어 가능
  - 커밋: a74b413

- **Cloud SQL 네트워크 격리**
  - VPC Peering 방식 비활성화 (전체 VPC 접근)
  - PSC Endpoint 방식 활성화 (Private subnet만 접근)
  - DMZ zone → Cloud SQL 접근 차단
  - 3-tier 아키텍처 준수 (DMZ → Private → DB)
  - 커밋: 6463e4c

### 문서화 (Documentation)

- **Work History 추가**
  - 2025-12-01.md: DNS Peering, SSH 접근 제어, Cloud SQL PSC Endpoint 전환 전체 과정 기록
  - 파일: `docs/changelog/work_history/2025-12-01.md`

---

## [미배포] - 2025-11-20

### 추가 (Added)

- **로드밸런서 템플릿 레이어(web/app/lobby)**
  - `proj-default-templet/70-loadbalancers/`에 jsj-game-n에서 검증된 web/app/lobby 구성을 그대로 추가
  - 각 디렉터리는 Terragrunt, main/variables/outputs, 예제 tfvars를 포함하여 즉시 배포 가능
  - Jenkins/Terragrunt 의존성(`auto_instance_groups`)까지 포함되어 신규 프로젝트 생성 시 별도 수작업 불필요
  - 커밋: `777c1e4`, `140da48`
- **Cloud DNS 모듈 및 레이어 추가**
  - 새로운 모듈: `modules/cloud-dns`
    - Public/Private DNS Managed Zone 지원
    - DNS 레코드 관리 (A, AAAA, CNAME, MX, TXT, PTR 등 모든 레코드 타입)
    - DNSSEC 지원 (Public Zone)
    - Private DNS: VPC 네트워크 연결, DNS Forwarding, DNS Peering
    - DNS Policy: Inbound Forwarding, DNS 로깅, 대체 네임서버
    - 유연한 설정: Reverse Lookup, 커스텀 DNSSEC 키, 라벨 지원
  - 새로운 레이어: `12-dns`
    - Public DNS Zone: 외부 공개 도메인 관리 (웹사이트, 서비스)
    - Private DNS Zone: 내부 서비스 이름 해석 (VPC 내부)
    - Hybrid DNS: 온프레미스 DNS 서버 연동 (Forwarding)
    - DNS Peering: 여러 프로젝트 간 DNS 공유
    - naming 모듈 통합: 일관된 Zone 이름 및 라벨 자동 생성
  - 배포 범위:
    - `proj-default-templet/12-dns`: 템플릿 레이어 (Public DNS 예제)
    - `environments/LIVE/jsj-game-m/12-dns`: Private DNS (game-m.internal.)
    - `environments/LIVE/jsj-game-n/12-dns`: Private DNS (game-n.internal.)
  - 문서화:
    - 상세한 README.md: 7가지 사용 시나리오 예제 포함
    - terraform.tfvars.example: 주석이 포함된 설정 가이드
    - 입력/출력 변수 전체 문서화
  - 필수 API: `dns.googleapis.com`

### 수정 (Fixed)

- **Cloud SQL 읽기 복제본 기본값/Null 처리 보강**
  - Terragrunt가 region/name 입력을 주입하기 전에 Jenkins에서 `terraform apply`를 실행하면 `trimspace(null)` 오류가 발생하던 문제 해결
  - `proj-default-templet` 및 `environments/LIVE/jsj-game-n`의 60-database 레이어에서 읽기 복제본 map을 재가공하여 region/name이 비어 있으면 기본값(`master region`, `{db_instance_name}-read-XX`)을 자동 채움
  - variables.tf에서 `name`, `region`을 optional로 선언해 Terraform validation 단계에서 실패하지 않도록 조정
  - 커밋: `b7fee4a`, `7c02390`, `aeb8bc9`, `013d499`, `ca68cd8`
- **20-storage Terragrunt locals 오류 수정**
  - CORS 자동화 도입 직후 Terragrunt locals 간 참조에서 `local.` 접두사가 누락되어 Jenkins 실행이 실패하던 문제 해결
  - 템플릿과 `jsj-game-n` 환경 모두 locals 가독성을 유지하면서도 안전하게 평가되도록 수정
  - 커밋: `3946d90`
- **Jenkins 프로젝트 생성 워크플로우 간소화**
  - 문제: Jenkins에서 신규 브랜치를 생성하고 PR을 만드는 복잡한 프로세스
  - 해결: 433_code 브랜치에 직접 커밋하고 GitHub에 푸시하는 방식으로 단순화
  - 변경 사항:
    - `Jenkinsfile.create-project`: 브랜치 생성/PR 생성 stage 제거, 433_code 브랜치로 직접 전환
    - `scripts/create_project.sh`: 브랜치 생성 로직 제거, 현재 브랜치에 커밋만 수행
    - CREATE_PR 파라미터 제거
  - detached HEAD 문제 해결: checkout 후 명시적으로 `git checkout 433_code` 실행
  - 파일: `Jenkinsfile.create-project`, `scripts/create_project.sh`

- **70-loadbalancers 모듈 경로 오류 수정**
  - 문제: proj-default-templet과 environments 간 디렉토리 깊이 차이로 모듈 참조 실패
  - 원인: 템플릿 위치 `proj-default-templet/70-loadbalancers/example-http`는 3단계 상위로 modules 접근, 배포 위치 `environments/LIVE/project/70-loadbalancers/example-http`는 6단계 상위 필요
  - 1차 시도: create_project.sh에서 sed로 3단계→6단계 변환 추가
  - 최종 해결: 템플릿을 처음부터 6단계 경로로 설정, sed 변환 로직 제거
  - 변경 내용:
    - `proj-default-templet/70-loadbalancers/example-http/main.tf`: `../../../../modules` → `../../../../../modules`
    - `scripts/create_project.sh`: 불필요한 step 6/6 제거 (15줄 코드 삭제)
  - 결과: 템플릿을 그대로 복사하면 올바른 경로가 되도록 단순화
  - 커밋: 0c83758

- **create_project.sh Jenkinsfile 치환 로직 개선**
  - 문제: Jenkinsfile TG_WORKING_DIR에 'LIVE'가 하드코딩되어 QA/STG 환경 생성 불가
  - 해결: 환경변수 기반 동적 치환으로 LIVE/QA/STG 모두 대응
  - 변경 내용:
    - `terraform_gcp_infra` 경로를 Configuration 섹션으로 이동
    - sed 패턴: `environments/LIVE/[^']*'` → `environments/[^/]*/[^']*'`
  - 파일: `scripts/create_project.sh`
  - 커밋: 089c10b

- **65-cache variables.tf 누락 변수 추가**
  - 문제: terraform.tfvars에 `deletion_protection = false` 있지만 variables.tf에 선언 없어서 "undeclared variable" 경고 발생
  - 원인: 65-cache는 in-place 실행 방식이라 레이어 자체의 variables.tf에도 변수 선언 필요 (모듈에만 있으면 부족)
  - 해결: 레이어 variables.tf에 필요한 변수들 추가
    - `deletion_protection` (bool, default: true)
    - `enterprise_node_type` (string)
    - `enterprise_authorization_mode` (string)
    - `enterprise_transit_encryption_mode` (string)
    - `enterprise_redis_configs` (map)
  - 영향: proj-default-templet, jsj-game-m, jsj-game-n
  - 결과: Terraform Warning 완전 해결
  - 커밋: de00df3

### 개선 (Improved)

- **로드밸런서 네이밍 자동화**
  - Terragrunt locals가 `project_name`과 디렉터리명(web/app/lobby)을 이용해 backend/url-map/http-proxy/forwarding-rule/static-ip/health-check 이름을 자동 생성
  - 템플릿과 `jsj-game-n` 환경 모두 tfvars에서 이름을 제거하고 필요 시에만 override하도록 정리
  - Jenkins나 Terragrunt 이외 실행에서도 일관된 네이밍 가능
  - 커밋: `249552d`, `292f933`
- **20-storage CORS 도메인 자동화**
  - Terragrunt가 `project_name`을 기반으로 assets 버킷의 기본 CORS origin(`https://{project_name}.example.com`, `https://cdn.{project_name}.example.com`)을 생성
  - tfvars에서 값을 명시하면 그대로 사용하며, 템플릿·jsj-game-n 환경 모두 동일 로직 적용
  - 커밋: `8c48ec1`
- **스크립트 유지보수성 향상**
  - `scripts/create_project.sh`: 하드코딩된 값을 Configuration 섹션으로 이동
    - `DEFAULT_REGION_BACKUP`, `DEFAULT_REMOTE_STATE_*`, `DEFAULT_ORG_ID`, `DEFAULT_BILLING_ACCOUNT`
    - `CONFIG_FILE_NAME`, `TEMPLATE_DIR_NAME`, `ENVIRONMENTS_DIR_NAME`, `TF_GCP_INFRA_DIR_NAME`
  - `scripts/gcp_project_guard.sh`: Configuration 섹션 추가 + 전체 한글 주석
  - `scripts/setup_slack_webhook.sh`: Configuration 섹션 추가 + 한글 메시지

- **Terragrunt mock_outputs 개선**
  - 70-loadbalancers의 mock_outputs_allowed_terraform_commands에 "init" 추가
  - 기존: `["validate", "plan"]` → 수정: `["init", "validate", "plan"]`
  - terragrunt init 시 "detected no outputs" 에러 방지
  - 영향: proj-default-templet, jsj-game-m (lobby, web), jsj-game-n (example-http)

- **문서 업데이트**
  - `docs/CREATE_NEW_PROJECT.md`: 신규 프로젝트 생성 가이드 전면 개편
    - PR 생성 관련 내용 제거
    - 433_code 브랜치 직접 사용 방식으로 업데이트
    - detached HEAD 트러블슈팅 추가
  - 로컬 PC에서 `git pull origin 433_code`로 바로 받는 방식으로 간소화

---

## [미배포] - 2025-11-18

### 추가 (Added)

- **Redis Cluster deletion protection 설정**: `modules/memorystore-redis`에 `deletion_protection` 변수 추가
  - Enterprise Tier(`google_redis_cluster`)의 `deletion_protection_enabled` 속성을 변수로 제어
  - 기본값: `true` (프로덕션 보호)
  - 개발/테스트 환경에서는 `false`로 설정하여 자유로운 삭제 가능
  - `proj-default-templet/65-cache` 및 `jsj-game-m/65-cache`에 `deletion_protection = false` 설정 추가
  - modules/memorystore-redis/variables.tf:165-169, main.tf:78

### 수정 (Fixed)

- **Terragrunt destroy 시 dependency 에러 해결**: 환경변수 기반 `skip_outputs` 제어
  - 문제: `terragrunt run-all destroy` 실행 시 50-workloads가 먼저 삭제되어 outputs가 없는데, 70-loadbalancers가 `dependency.workloads.outputs.instance_groups`를 읽으려고 해서 에러 발생
  - 시도한 방법들:
    - `mock_outputs_merge_with_state = true` → deprecated로 작동 안 함
    - `mock_outputs_merge_strategy_with_state = "shallow"` → 작동 안 함
    - `get_terraform_command()` 조건 분기 → dependency 평가 시점에 이미 에러 발생
    - dependency 블록 완전 제거 → destroy는 성공하지만 자동 매핑 기능 상실
  - 최종 해결: `get_env()` 함수로 환경변수 기반 동적 제어
  - 핵심 코드:
    ```hcl
    dependency "workloads" {
      config_path = "../../50-workloads"
      skip_outputs = get_env("SKIP_WORKLOADS_DEPENDENCY", "false") == "true"
      mock_outputs = { instance_groups = {} }
    }
    inputs = merge(
      local.common_inputs,
      local.layer_inputs,
      { auto_instance_groups = {...} }  # 항상 정의, try()로 안전 처리
    )
    ```
  - 사용법:
    - 일반 apply/plan: `terragrunt apply` (자동 매핑 ✅)
    - run-all destroy: `SKIP_WORKLOADS_DEPENDENCY=true terragrunt run-all destroy`
  - 영향받는 파일:
    - `environments/LIVE/jsj-game-m/70-loadbalancers/{lobby,web}/terragrunt.hcl`
    - `proj-default-templet/70-loadbalancers/example-http/terragrunt.hcl`
  - 장점: 자동 instance_groups 연결 기능 유지 + destroy 안정성 확보 + 유연한 제어
  - README 추가: 사용법 및 설정 가이드 문서화

- **Service Networking Connection destroy 에러 해결**: `deletion_policy = "ABANDON"` 추가
  - 문제: Terraform Provider Google 5.x에서 Service Networking Connection 삭제 실패
    - 에러: "Failed to delete connection; Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection."
    - CloudSQL/Redis가 이미 삭제되었는데도 발생
    - Provider 4.x에서는 문제없었으나 5.x에서 `removePeering` → `deleteConnection` 메서드 변경으로 regression
  - 해결: `modules/network-dedicated-vpc/main.tf`에 `deletion_policy = "ABANDON"` 추가
  - 동작 방식: destroy 시 GCP에서 실제로 삭제하지 않고 Terraform state에서만 제거
  - 안전성: VPC나 프로젝트 삭제 시 Service Networking Connection도 자동으로 정리됨
  - 장점: 슬립타임 불필요, 항상 성공, 완전 자동화 가능
  - 참고: GitHub Issue #16275, #19908
  - modules/network-dedicated-vpc/main.tf:142

### 운영 (Operations)

- **기존 Redis Cluster deletion protection 해제**: gcloud 명령으로 jsj-game-m 프로젝트의 Redis Cluster 삭제 보호 비활성화
  - 명령어: `gcloud redis clusters update game-m-prod-redis --region=asia-northeast3 --no-deletion-protection --project=jsj-game-m`
  - 결과: `deletionProtectionEnabled: false` 확인
  - 이후 Terraform destroy 가능 상태로 전환

## [미배포] - 2025-11-12

### 추가 (Added)

- **Memorystore Enterprise 지원**: `modules/memorystore-redis`가 STANDARD/BASIC 경로와 별도로 `google_redis_cluster` 기반 Enterprise·Enterprise Plus 구성을 지원
  - `replica_count`, `shard_count`, `enterprise_*` 입력을 통해 PSC 연결, 노드 타입, 암호화, Redis 설정을 제어
  - modules README 및 템플릿/jsj-game-m 65-cache tfvars/예제/가이드에 Enterprise 사용법을 문서화
- **Memorystore PSC 자동 구성**: 10-network 레이어가 `google_network_connectivity_service_connection_policy` 리소스를 제공해 Enterprise 배포 전 PSC 정책을 자동 생성
  - 새 변수(`enable_memorystore_psc_policy`, `memorystore_psc_region`, `memorystore_psc_subnet_name`, `memorystore_psc_connection_limit` 등)로 정책을 제어
  - 템플릿 및 jsj-game-m tfvars에서 기본적으로 활성화하고 README에 선행 조건을 명시

### 수정 (Fixed)

- **Jenkinsfile 단일 레이어 실행 시 경로 문제 해결**: `--working-dir` 플래그를 사용하여 terragrunt.hcl 파일을 찾지 못하는 문제 수정
  - 단일 레이어 실행 시 `dir()` 블록 안에서 직접 `terragrunt init`을 실행하면 terragrunt.hcl 파일 인식 실패
  - 모든 terragrunt 명령(`init`, `plan`, `apply`, `destroy`)에 `--working-dir` 플래그를 사용하도록 변경
  - 영향을 받는 파일:
    - `environments/LIVE/jsj-game-k/Jenkinsfile`
    - `environments/LIVE/jsj-game-l/Jenkinsfile`
    - `proj-default-templet/Jenkinsfile`
    - `.jenkins/Jenkinsfile.template`
  - `all` 레이어 실행 패턴과 단일 레이어 실행 패턴 일관성 확보
- **로드 밸런서 자동 백엔드 연동 복구**: Terragrunt가 `50-workloads` 출력(Instance Group self link)을 읽지 못해 새 VM이 LB 백엔드에 자동 등록되지 않던 문제 해결
  - 기존에는 `dependencies { paths = [...] }`만 선언되어 실행 순서만 보장되고 outputs는 전달되지 않았음
  - `dependency "workloads"` 블록을 추가해 `instance_groups` output을 실제 입력으로 주입하고, plan/validate 시 사용 가능한 mock output을 정의
  - 템플릿 및 운영 환경(`proj-default-templet`, `jsj-game-k`, `jsj-game-l`)의 `70-loadbalancer/terragrunt.hcl`에 동일하게 적용
- **Cloud SQL 읽기 복제본 생성 안정화**: `modules/cloudsql-mysql`에서 `replica_configuration`/`ip_configuration` 블록을 조건부로 생성하고 기본 네트워크/IPv4 옵션을 자동 상속해 불필요한 required argument 오류를 제거
  - 템플릿 및 jsj-game-m tfvars 예시에 기본 읽기 노드 구성을 추가해 Jenkins/Terragrunt 실행 시 바로 활용 가능

## [미배포] - 2025-11-11

### 수정 (Fixed)

- Memorystore Redis: `REDIS_7_X` 값이 GCP API에서 아직 허용되지 않아 apply가 실패하던 문제를 `REDIS_6_X` 기본값 및 허용 버전(validation) 추가로 해결
  - 모듈(`modules/memorystore-redis`)과 각 레이어/예제(tfvars/variables, jsj-game-k 포함)에서 기본 버전을 `REDIS_6_X`로 통일
  - README/가이드에 지원 버전 목록을 명시하고 Jenkins/Quick Setup 흐름과 일치하도록 문구 업데이트
- Terragrunt 루트 파일 이름을 `terragrunt.hcl` → `root.hcl`로 변경해 0.93 이후 경고/미래 에러를 사전 차단
  - `proj-default-templet/root.hcl`, `environments/LIVE/jsj-game-k/root.hcl`을 기준으로 모든 레이어 include가 `find_in_parent_folders("root.hcl")` 형태를 사용
  - Quick Setup/README/Jenkins 가이드 등 문서에서도 새 파일명을 반영

### 변경 (Changed)

- 네트워크 레이어(10-network)
  - `additional_subnets` + `dmz/private/db_subnet_name` 조합으로 DMZ/Private/DB 전용 서브넷을 선언하도록 템플릿·환경 tfvars/README 갱신
  - `nat_subnet_self_links`를 이용해 Cloud NAT 적용 대상을 DMZ 서브넷으로 제한하는 패턴 문서화
  - `subnet_primary_cidr`/`subnet_backup_cidr`/`pods_cidr`/`services_cidr` 변수를 제거하고, 모든 서브넷을 `additional_subnets`에서 직접 정의하도록 코드·문서·예제를 정리
  - DMZ/Private/DB 서브넷 모두가 Cloud NAT를 사용할 수 있도록 `nat_subnet_self_links` 계산 로직을 `compact([dmz, private, db])` 형태로 확장
- 워크로드 레이어(50-workloads) 및 `modules/gce-vmset`
  - `instances` 맵이 `hostname`, `image_family`, `image_project`, `startup_script_file` 등을 인스턴스별로 override하도록 확장
  - `startup_script_file` 값을 실제 스크립트 파일(`scripts/*.sh`)에서 로드하도록 구현하고 스크립트는 `/usr/bin/env bash` + `set -euo pipefail` 표준을 적용
  - 실제 환경(jsj-game-k)과 템플릿 tfvars/example/README를 모두 업데이트해 DMZ/Private 서브넷 self-link, 역할별 스크립트, OS mix 사용 예시를 제공
- Load Balancer/문서
  - 내부 LB가 Private 서브넷을 바라보도록 `internal_subnetwork_self_link` 사용법을 README와 tfvars.example에 명시
  - 최상위 README/Quick Reference/Quick Setup 등에서 새 네트워크/워크로드 구조(DMZ·Private·DB, per-instance VM)와 Terragrunt 0.93 실행 패턴을 일관되게 설명

## [미배포] - 2025-11-10

### 변경 (Changed)

- 템플릿 코드 최신화(동기화)
  - 00-project: bootstrap remote state 기반 동적 폴더 참조 추가 (`folder_product/region/env` 입력 사용, `folder_id` 미설정 시 자동)
  - 65-cache: Redis 위치를 zone(default_zone) 기반으로 계산, provider region을 `region_primary`로 통일
  - terragrunt.hcl: GCS remote_state에 `project`/`location` 필수 값 추가
- Bootstrap: 관리 옵션 토글 추가 및 문서 정리
  - variables: `manage_folders`, `manage_org_iam`, `enable_billing_account_binding`
  - README/가이드 전반에서 명칭을 `jsj-system-mgmt`, `jsj-terraform-state-prod`로 정리
  - Provider 정책: 전 레이어에 `user_project_override=true`, `billing_project=var.project_id` 적용(ADC 의존 제거). 단, 00-project는 예외(프로젝트 생성/필수 API 활성화 담당)
  - 10-network: Service Networking 프로젝트 서비스 조작으로 인한 403 방지를 위해 초기 API 전파 대기 및 단계별 대기 로직 추가(Cloud Resource Manager → Service Usage → Service Networking 순), PSC 리소스는 모듈 일원화
  - Jenkins 파이프라인: clean checkout, 캐시(.terragrunt-cache/.terraform/tfplan) 정리, `terragrunt run --queue-include-dir '00-project' --all plan`으로 선 검증, 전체 Apply는 `run --all apply` 기반 최신 코드/상태 기준 의존 순서대로 적용

### 추가 (Added)

- 신규 환경 `jsj-game-k` 생성 (LIVE)
  - `common.naming.tfvars`, `terragrunt.hcl`, `Jenkinsfile`에 jsj-game-k 식별자 반영
- Bootstrap 실제 적용 완료: folder_structure 출력 확인(games/kr-region, us-region)
- 00-project/10-network에 초기 전파 지연을 흡수하기 위한 대기 로직(time_sleep) 도입

### 제거 (Removed)

- 기존 `jsj-game-j` 환경 디렉터리 제거 (템플릿 최신화 반영된 `jsj-game-k`로 이관)

## [미배포] - 2025-11-09

### 추가 (Added)

- **GCP 폴더 구조 자동화**: 게임별로 다른 리전 조합을 지원하는 유연한 폴더 구조
  - Bootstrap에 3차원 for_each 구조 추가 (게임 × 리전 × 환경)
  - `product_regions` 맵에서 게임별 사용 리전 정의 가능
    - games: kr-region, us-region
    - games2 추가 예시: jp-region, uk-region
    - games3 추가 예시: kr-region만

  - 환경(LIVE/Staging/GQ-dev)은 모든 조합에 자동 생성
  - 생성된 폴더:
    - games/kr-region/LIVE (folders/587862617074)
    - games/kr-region/Staging (folders/832653143511)
    - games/kr-region/GQ-dev (folders/873010178233)
    - games/us-region/LIVE (folders/577170857863)
    - games/us-region/Staging (folders/902417803159)
    - games/us-region/GQ-dev (folders/1024560108932)
  - Output: `folder_structure[product][region][env]` 중첩 맵 구조
  - 관련 커밋: `2982d65`, `56a7306`
- **games2 폴더 정식 추가**: Bootstrap `product_regions` 맵에 `games2 = ["jp-region", "uk-region"]`을 반영하고 실제 폴더까지 배포해 멀티 게임 구조를 활용 가능하도록 확장
  - README에 `product_regions` 편집 방법을 추가해 다른 팀이 새 게임/리전 조합을 쉽게 정의할 수 있도록 문서화
- **Terragrunt 입력으로 폴더 선택**: jsj-game-j 00-project가 `folder_product/folder_region/folder_env` 입력을 참조하도록 수정해 하드코딩 없이 폴더 조합을 전환 가능

- **Bootstrap Remote State 자동 참조**: 프로젝트에서 폴더 ID 자동 참조
  - `terraform_remote_state` data source 추가
  - Bootstrap의 output을 자동으로 참조 (GCS backend: `bucket = "jsj-terraform-state-prod", prefix = "bootstrap"`)
  - terraform.tfvars에서 folder_id 수동 입력 제거
  - 새 프로젝트 생성 시 수동 작업 최소화
  - 사용 예시:

    ```hcl
    data "terraform_remote_state" "bootstrap" {
      backend = "gcs"
      config = {
        bucket = "jsj-terraform-state-prod"
        prefix = "bootstrap"
      }
    }
    folder_id = data.terraform_remote_state.bootstrap.outputs.folder_structure["games"]["kr-region"]["LIVE"]
    ```

  - 관련 커밋: `f6fdda8`, `353aa10`

### 수정 (Fixed)

- project-base HCL 표현 오류 수정: 필수 API(core)와 사용자 API 목록을 `setunion`으로 병합하고 `locals` 위치 정리(초기화 실패 방지)
- 00-project → 모듈에 `manage_default_logging_bucket`/`logging_api_wait_duration` 전달 누락 보완, env tfvars에서 초기 1차 적용 시 로그 버킷 스킵 가능하도록 문서/예제 반영
- **Cloud Logging API 활성화 타이밍 이슈 해결**: 명시적 depends_on으로 API 대기 보장
  - 문제: google_logging_project_bucket_config가 logging API 활성화 전에 실행
  - 에러: `Error 403: Cloud Logging API has not been used in project 110061486541`
  - 해결: `depends_on = [google_project_service.services["logging.googleapis.com"], ...]`
  - for_each 맵에서 특정 API 명시적 참조로 타이밍 문제 해결
  - 60초 대기 시간과 함께 이중 보호 메커니즘 적용
  - 파일: `modules/project-base/main.tf:79-82`
  - 관련 커밋: `effe94a`

### 변경 (Changed)

- **Bootstrap 폴더 리소스 구조 변경**: 정적 리소스 → for_each 동적 생성
  - State 이동:
    - `google_folder.games` → `google_folder.products["games"]`
    - `google_folder.kr_region` → `google_folder.regions["games/kr-region"]`
    - `google_folder.live` → `google_folder.environments["games/kr-region/LIVE"]`
    - `google_folder.staging` → `google_folder.environments["games/kr-region/Staging"]`
    - `google_folder.gq_dev` → `google_folder.environments["games/kr-region/GQ-dev"]`
  - 기존 폴더 유지하면서 새로운 구조로 전환 완료

## [미배포] - 2025-11-07

### 추가 (Added)

- **jsj-game-j 환경 생성**: 신규 프로젝트 환경 완전 구성
  - 9개 인프라 레이어 전체 설정 완료 (00-project ~ 70-loadbalancer)
  - `common.naming.tfvars` 생성 (project_id: jsj-game-j, region: asia-northeast3)
  - `Jenkinsfile` 추가 (TG_WORKING_DIR: terraform_gcp_infra/environments/LIVE/jsj-game-j)
  - `terragrunt.hcl` 구성 (state prefix: jsj-game-j)
  - 총 72개 파일 추가
- **work_history 폴더 구조**: 작업 이력을 날짜별 파일로 관리
  - `work_history/2025-11-07.md` 생성
  - `04_WORK_HISTORY.md`를 인덱스 파일로 변경
  - 날짜별 파일 링크 및 작업 가이드 추가

### 수정 (Fixed)

- **65-cache 레이어 zone 설정 이슈 해결**: Redis는 zone 필요, region만 제공되던 문제 수정
  - 1차 시도: `terraform.tfvars`에 region 직접 지정 → 중앙 관리 원칙 위반
  - 2차 수정: `main.tf`에서 `module.naming.default_zone` 사용 → zone 자동 생성
  - 3차 수정: `provider "google"`가 `var.region_primary` 사용하도록 변경
  - 최종 구조:
    - provider.region = "asia-northeast3" (API 호출용 region)
    - redis.region = "asia-northeast3-a" (리소스 배치용 zone, naming 모듈 자동 생성)
    - alternative_zone = "asia-northeast3-b" (suffix 'b' 사용)
  - 관련 커밋: `696493a`, `c9dae19`, `a25b878`, `11c8667`
- **Terragrunt remote_state 설정 구조 수정**: skip 옵션 위치 변경
  - `skip_bucket_creation`, `skip_bucket_versioning`, `skip_bucket_accesslogging`을 `config` 블록 외부로 이동
  - 이 옵션들은 Terragrunt 자체 설정이므로 `remote_state` 블록에 직접 배치
  - `config` 블록에서 `project`, `location` 제거 (Terraform GCS backend가 인식하지 못하는 파라미터)
  - `config` 블록에는 Terraform backend가 인식하는 `bucket`, `prefix`만 유지
  - "Unsupported argument" 오류 해결
  - "Duplicate backend configuration" 오류 해결
- **Terragrunt backend 파일 자동 생성**:
  - `environments/LIVE/jsj-game-h/terragrunt.hcl`과 `proj-default-templet/terragrunt.hcl`에 `generate` 블록 추가
  - 각 레이어 디렉터리에 `backend.tf`를 자동 생성하며 기존 파일을 덮어쓰도록 설정
  - Terraform 코드(`main.tf`)에서 빈 `backend "gcs" {}`를 제거해 중복 선언 없이 Terragrunt 설정만 사용
  - Jenkins에서 `terraform init` 재실행 시 더 이상 `backend.tf` 수동 관리가 필요 없음

### 변경 (Changed)

- **실제 배포 환경 ID 교체**: 기존 `jsj-game-g` 프로젝트 ID가 전역에서 사용 중이라 `jsj-game-h`로 교체하고 Terragrunt remote_state prefix 및 naming 입력을 모두 갱신 (추가로 실험용 `jsj-game-i` 환경을 동일 템플릿으로 준비)
- **문서 업데이트**: `05_quick setup guide.md`의 terragrunt.hcl 예제를 최신 구조로 갱신
  - 올바른 remote_state 설정 구조 반영
  - skip 옵션들의 올바른 위치 문서화

## [미배포] - 2025-11-06

### 추가 (Added)

- **Bootstrap Service Account 생성**: Jenkins CI/CD 자동화를 위한 Service Account
  - `jenkins-terraform-admin@delabs-system-mgmt.iam.gserviceaccount.com` 생성
  - Bootstrap Terraform 코드로 관리 (Infrastructure as Code)
  - 조직 권한 없는 환경에서 프로젝트별 권한 부여 방식 지원
- **GCP 프로젝트 수동 생성 프로세스**: 조직 없는 환경 대응
  - `jsj-game-h` 프로젝트 생성 (기존 `jsj-game-g` ID 충돌로 교체, Project Number는 생성 후 업데이트)
  - 추가 테스트용 `jsj-game-i` 템플릿 환경 구성
  - Service Account에 프로젝트별 Editor 권한 부여
  - Billing account 수동 연결 방식
- **Jenkins GCP 인증 설정**: Jenkinsfile에 GCP 인증 통합
  - `GOOGLE_APPLICATION_CREDENTIALS` 환경변수 추가
  - Jenkins Credential ID: `gcp-jenkins-service-account`
  - Secret file 타입으로 Service Account Key 관리
- **Service Account 필수 권한 설정**:
  - `delabs-system-mgmt` 프로젝트: `roles/storage.admin` (State 버킷 접근)
  - 각 워크로드 프로젝트: `roles/editor` (리소스 관리)

### 변경 (Changed)

- **Jenkinsfile Working Directory 수정**: 절대 경로 사용
  - `TG_WORKING_DIR`을 상대 경로 '.'에서 절대 경로로 변경
  - 예: `terraform_gcp_infra/environments/LIVE/jsj-game-h`
  - 템플릿 디렉터리와의 충돌 방지
- **terragrunt.hcl GCS Remote State 설정 강화**: 필수 파라미터 추가
  - `project`: GCS 버킷이 위치한 프로젝트 (delabs-system-mgmt)
  - `location`: 버킷 위치 (US)
  - `jsj-game-h` 및 `proj-default-templet` 모두 적용
- **Terragrunt in-place 실행**: `.terragrunt-cache` 사용 안 함
  - 모든 레이어 `terragrunt.hcl`에서 `terraform.source` 블록 제거
  - 현재 디렉토리에서 직접 실행 (상대 경로 모듈 참조 유지)
  - `.terragrunt-cache`로 복사하지 않아 더 빠른 실행
  - 18개 레이어 파일 업데이트 (jsj-game-h 9개 + proj-default-templet 9개)
- **Terragrunt region 기본값 문서화**: 모든 레이어 tfvars/example/README에서 `region = ""` 패턴을 제거하고, 필요 시 주석 해제 방식으로 Terragrunt 기본값(`region_primary`)을 재사용하도록 안내
- **Bootstrap Cloud Billing API 활성화**: `delabs-system-mgmt` 프로젝트가 자동으로 `cloudbilling.googleapis.com`을 사용하도록 설정, 신규 프로젝트 생성 시 Billing API 오류 방지
- **Bootstrap Service Usage API 활성화**: 프로젝트 생성/서비스 사용 검증을 위해 `serviceusage.googleapis.com`을 자동 활성화
- **Project 부모/결제 지정 강화**:
  - `modules/project-base`가 `org_id` 입력을 지원해 폴더가 없을 때도 서비스 계정이 조직 하위에 프로젝트를 생성 가능
  - 환경 루트 `terragrunt.hcl`의 `inputs`로 `org_id`, `billing_account` 등 공통 값을 중앙 관리

### 수정 (Fixed)

- **Jenkinsfile 경로 이슈 해결**: workspace root vs Jenkinsfile 위치
  - Jenkins Pipeline은 항상 workspace root에서 시작
  - Jenkinsfile 위치와 무관하게 절대 경로 필요
- **GCS Remote State 파라미터 누락 오류 해결**:
  - "Missing required GCS remote state configuration project" 오류 수정
  - "Missing required GCS remote state configuration location" 오류 수정
- **Terragrunt 모듈 경로 문제 해결**:
  - "Unreadable module directory" 오류 수정
  - `.terragrunt-cache`에서 상대 경로(`../../../../modules`) 찾지 못하는 문제 해결
  - `terraform.source` 제거로 in-place 실행하여 해결
- **GCS 버킷 validation 보완**:
  - `public_access_prevention`, `retention_policy_days`가 `null`일 때 Terraform이 실패하던 문제 해결
  - Terragrunt에서 선택 입력을 생략해도 안전하게 통과

## [미배포] - 2025-11-05

### 추가 (Added)

- **Jenkins CI/CD 통합**: Jenkins를 통한 자동화된 Terragrunt 배포 지원
  - `Jenkinsfile`을 `terraform_gcp_infra/` 루트에 배치
  - Plan/Apply/Destroy 파라미터 선택 가능
  - 전체 스택 또는 개별 레이어 실행 지원
  - 승인 단계가 있는 안전한 배포 Pipeline (30분 타임아웃, admin 전용)
- **첫 번째 실제 환경 생성**: `environments/LIVE/jsj-game-h` (초기에는 `jsj-game-g`로 준비했으나 ID 충돌로 교체)
  - Project ID: jsj-game-h
- **추가 환경 템플릿**: `environments/LIVE/jsj-game-i` (jsj-game-h를 복제해 새 프로젝트 ID 실험)
  - Region: asia-northeast3 (Seoul)
  - Organization: jsj
- **중앙 관리 Service Account 문서화**: Jenkins용 GCP 인증 방법 추가
  - `delabs-system-mgmt` 프로젝트의 `jenkins-terraform-admin` SA 사용
  - 하나의 Key로 모든 프로젝트 관리
  - Key 관리 포인트 최소화 및 중앙 집중식 권한 관리

### 변경 (Changed)

- **디렉터리 구조 재정리**: 템플릿과 실제 환경 분리
  - `proj-default-templet`을 `terraform_gcp_infra/` 루트로 이동
  - `environments/LIVE/`는 실제 배포 환경만 포함
  - 템플릿 복사 시 더 명확한 구조 제공
- **환경별 Jenkinsfile 구조**: 각 환경이 독립적인 Jenkinsfile 보유
  - `Jenkinsfile`을 `environments/LIVE/jsj-game-h/` 로 이동
  - `.jenkins/Jenkinsfile.template` 생성 (재사용 가능한 템플릿)
  - `TG_WORKING_DIR`을 절대 경로로 변경 (workspace root 기준)
  - Jenkins Job Script Path: `environments/LIVE/{project}/Jenkinsfile`

### 문서 (Documentation)

- `00_README.md`: Jenkins CI/CD 통합 섹션 추가, 디렉터리 구조 업데이트
- `03_QUICK_REFERENCE.md`: 세션 12 작업 내역 추가, 경로 업데이트
- `05_quick setup guide.md`: 템플릿 경로 수정
- `02_CHANGELOG.md`: 프로젝트 재구성 및 Jenkins 통합 기록

### 수정 (Fixed)

- **Network 모듈 출력 속성 수정**: `google_service_networking_connection` 리소스의 출력을 `.self_link`에서 `.id`로 변경
  - `.self_link` 속성이 존재하지 않아 destroy 시 에러 발생하던 문제 해결
  - `modules/network-dedicated-vpc/main.tf:148` 및 README 문서 업데이트
- **Network 모듈 depends_on 수정**: Terraform이 지원하지 않는 조건부 `depends_on` 표현식을 정적 의존성 리스트로 변경
  - `modules/network-dedicated-vpc/main.tf:131` 수정
- **Redis 모듈 문서 개선**: `region` 변수가 실제로는 **zone**이어야 한다는 것을 명확히 문서화
  - `modules/memorystore-redis/variables.tf`, `README.md` 주석 및 설명 업데이트
  - 잘못된 region 입력 시 "Zone is not within instance Region" 오류 발생 방지
  - `environments/LIVE/proj-default-templet/65-cache/terraform.tfvars`에 경고 주석 추가

### 추가 (Added)

- **프로젝트 템플릿 API 추가**: `proj-default-templet/00-project/terraform.tfvars`에 필수 API 추가
  - `sqladmin.googleapis.com` (Cloud SQL)
  - `redis.googleapis.com` (Memorystore Redis)

### 문서 (Documentation)

- `05_quick setup guide.md`에 Terragrunt & Naming 구조 개요 섹션 추가
  - common.naming.tfvars와 레이어별 terraform.tfvars 병합 구조 설명
  - naming 모듈을 통한 리소스 이름/라벨/기본 존 계산 흐름 문서화

### 운영 (Operations)

- `environments/LIVE/jsj-game-f` 전체 인프라 destroy 완료 (9개 레이어)
  - VPC 피어링 수동 삭제 (redis-peer, servicenetworking-googleapis-com)
  - Storage lien 수동 제거 후 프로젝트 리소스 정리 완료

## [미배포] - 2025-11-04

### 추가 (Added)

- `environments/prod/proj-default-templet` 전 레이어에 한글 `terraform.tfvars.example` 제공
  - 10-network/30-security/40-observability/50-workloads 레이어 예제 파일 신규 생성
  - 00-project/20-storage/60-database/70-loadbalancer 예제 파일을 한국어 설명으로 갱신
  - Private Service Connect, 서비스 계정, 로그 싱크 등 핵심 입력값에 대한 가이드 주석 강화
- `modules/memorystore-redis` 및 `environments/LIVE/proj-default-templet/65-cache` 레이어 추가로 Redis 캐시 템플릿 제공

### 변경 (Changed)

- `modules/gce-vmset` 선점형 VM 스케줄링을 Spot 제약에 맞게 자동 재시작 비활성화 및 유지보수 시 종료로 조정하여 배포 실패를 방지
- `environments/LIVE/proj-default-templet/60-database` 기본 설정을 Cloud SQL 고가용성(REGIONAL) + 삭제 보호 비활성 형태로 조정하고 문서를 업데이트 (필요 시 tfvars에서 true로 전환)
- `modules/naming`에 `redis_instance_name` 출력을 추가하고 ARCHITECTURE/QUICK_REFERENCE 문서를 Redis 캐시 레이어를 반영하도록 갱신
- `modules/observability`에 기본 Alert 정책 템플릿과 Notification Channel 입력을 추가하고, 40-observability 레이어가 GCE/Cloud SQL/Memorystore/HTTPS LB 경보를 기본 구성하도록 개선
- 10-network 레이어가 Cloud SQL Private IP를 위한 Service Networking 연결을 기본으로 예약하도록 템플릿 코드(및 예제 변수) 업데이트
  - `enable_private_service_connection`, `private_service_connection_prefix_length` 등 토글형 변수 추가
  - Terragrunt 템플릿에서도 동일한 네트워킹 구성이 기본 제공되도록 동기화
- 30-security 템플릿이 `modules/naming`을 참조하여 서비스 계정 접두어와 라벨을 공통 규칙으로 생성하도록 개선
- `modules/network-dedicated-vpc`에 Private Service Connect 예약/연결 리소스를 통합하고, 기존 예약 범위 재사용 및 서비스 이름 커스터마이즈 옵션을 추가
- README / ARCHITECTURE / QUICK_REFERENCE 문서에 Private Service Connect 흐름과 신규 tfvars 예제 복사 절차를 반영

### 운영 (Operations)

- `environments/prod/jsj-game-e` 네트워크 레이어 destroy 재시도 후 Service Networking 연결이 정상 해제되어 환경 전체 삭제 완료
- WSL 네트워크 제한으로 gcloud/gsutil 명령이 실패할 수 있음을 문서화하고, 콘솔을 통한 리소스 확인을 안내

## [미배포] - 2025-11-03

### 변경 (Changed)

- `environments/prod/proj-default-templet` 전역을 Terragrunt 구조로 전환
  - 루트 및 각 레이어에 `terragrunt.hcl` 추가하고 의존 관계를 선언해 실행 순서 자동화
  - Terraform backend 관리는 Terragrunt가 생성하는 `backend.tf` 파일로 이관되어 코드에 직접 backend 블록을 둘 필요가 없음
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

- **00_README.md**: naming 모듈 기반 중앙 집중식 naming 섹션 추가
  - naming 모듈과 공통 입력값의 역할 설명
  - 새 프로젝트 추가 가이드 개선
  - 단계별 프로젝트 생성 절차
- **03_QUICK_REFERENCE.md**: 세션 7 작업 내용 추가
- **02_CHANGELOG.md**: 변경 이력 업데이트

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

- **01_ARCHITECTURE.md (신규)**: 시각적 아키텍처 다이어그램 문서
  - 10개의 Mermaid 다이어그램
  - 전체 시스템 구조, State 관리, 배포 순서
  - 모듈 구조, GCP 리소스 배치, 네트워크 흐름
  - Terraform 실행 흐름, 설계 결정, 확장 로드맵
  - 모듈 구조 다이어그램 개선 (간단명료한 레이아웃)
- **모듈 README**: cloudsql-mysql, load-balancer 한글 문서 추가
- **메인 README**: 새 모듈 및 레이어 반영, 배포 순서 업데이트
- **WORK_HISTORY**: 세션 3, 4, 5 작업 상세 기록
- **03_QUICK_REFERENCE**: 빠른 참조 가이드 업데이트, 01_ARCHITECTURE.md 링크 추가
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
- **Cloud Logging API 대기/스킵 옵션 추가**:
  - `modules/project-base`에 `manage_default_logging_bucket` 플래그와 `time_sleep` 리소스를 도입해 Logging API 활성화 후 `_Default` 버킷 구성을 시작하기 전에 `logging_api_wait_duration`만큼 대기 (기본 60초)
  - 초기 부트스트랩에서 해당 버킷 구성을 건너뛰고 싶을 때 `manage_default_logging_bucket = false`로 설정 가능
  - 신규 프로젝트에서 API 전파 지연으로 `_Default` 버킷 생성이 반복적으로 403을 내던 문제 완화

<!-- markdownlint-enable MD005 MD007 MD013 MD024 -->
