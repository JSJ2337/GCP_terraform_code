# Terraform GCP Infrastructure - 작업 히스토리

이 문서는 프로젝트의 주요 작업 이력을 날짜별로 기록합니다.

---

## 📂 작업 이력 아카이브

상세한 작업 내역은 아래 날짜별 파일을 참조하세요:

### 2025년 12월

- **[2025-12-08](./2025-12-08.md)** - Instance Group 생성 문제 해결 (tfvars 우선순위), ICMP Firewall 추가
- **[2025-12-05](./2025-12-05.md)** - proj-default-templet 재구성, 문서 구조 개선
- **[2025-12-04](./2025-12-04.md)** - Cross-Project PSC Redis 연결, DNS Zone 충돌 해결
- **[2025-12-03](./2025-12-03.md)** - Cloud SQL 자동 네이밍 및 Password Lifecycle 관리 구현
- **[2025-12-02](./2025-12-02.md)** - Lock 파일 정리, IPv6 문제 해결, Cross-Project PSC 설정

### 2025년 11월

- **[2025-11-20](./2025-11-20.md)** - 서브넷·로드밸런서·Cloud SQL 읽기 복제본 자동화
- **[2025-11-17](./2025-11-17.md)** - Memorystore Enterprise/PSC 자동화 및 Cloud SQL 읽기 복제본 개선
- **[2025-11-13](./2025-11-13.md)** - LB 자동 백엔드 복구 및 jsj-game-k 환경 정리
- **[2025-11-12 (최신)](./2025-11-12.md)** - 템플릿·환경 재동기화 및 VM 디스크 영속화
- **[2025-11-12 문서 재구성]** - 📚 문서 구조 전면 재구성 (docs/ 디렉터리, 17개 신규 문서)
- **[2025-11-11](./2025-11-11.md)** - Terragrunt 0.93 CLI 적용 및 Jenkins 파이프라인 정비
- **[2025-11-11 Session 2](./2025-11-11-session2.md)** - DMZ/Private 네트워크·워크로드 템플릿 및 문서 전면 업데이트
- **[2025-11-11 Session 3](./2025-11-11-session3.md)** - 템플릿/파이프라인 동기화 및 Jenkins 안정화
- **[2025-11-10](./2025-11-10.md)** - 템플릿 최신화 및 jsj-game-k 환경 생성 (jsj-game-j 이관)
- **[2025-11-09](./2025-11-09.md)** - GCP 폴더 구조 자동화 및 유연한 게임/리전 조합 지원
- **[2025-11-07](./2025-11-07.md)** - jsj-game-j 환경 추가 및 65-cache zone 설정 이슈 해결
- **[2025-11-06](./2025-11-06.md)** - Jenkins CI/CD 통합 및 Terragrunt 실행 최적화
- **[2025-11-04](./2025-11-04.md)** - Private Service Connect 기본화 및 템플릿 정비
- **[2025-11-03](./2025-11-03.md)** - Terragrunt 기반 실행 구조 전환

### 2025년 10월

- **[2025-10-31](./2025-10-31.md)** - 네트워크/데이터베이스 모듈 안정화 및 jsj-game-d 환경 종료
- **[2025-10-29 Session 6](./2025-10-29-session6.md)** - Redis 캐싱 레이어 추가 및 Load Balancer 통합
- **[2025-10-29 Session 5](./2025-10-29-session5.md)** - Load Balancer 모듈 및 레이어 구현
- **[2025-10-29 Session 4](./2025-10-29-session4.md)** - 워크로드/데이터베이스 레이어 안정화
- **[2025-10-29 Session 3](./2025-10-29-session3.md)** - 관찰성 및 워크로드 레이어 구현
- **[2025-10-28](./2025-10-28.md)** - 초기 인프라 구축 및 모듈 설계

---

## 📋 최근 작업 요약

### 2025-12-08: Instance Group 생성 문제 해결 및 ICMP Firewall 추가
- ✅ terraform.tfvars가 terragrunt inputs를 덮어쓰는 문제 해결 (instance_groups, firewall_rules)
- ✅ gcp-gcby Instance Group subnet 불일치 해결 (gcby-subnet-private → gcby-live-subnet-private)
- ✅ 70-loadbalancers에 instance_group_ids output 추가
- ✅ 10-network에 ICMP firewall rule 추가 (배스천 ping 테스트용)
- ✅ gcp-web3, gcp-gcby 배스천 DNS 접속 테스트 완료 (SSH, MySQL, Redis)
- 🔗 커밋: `9a9275b`

### 2025-12-03: Cloud SQL 자동 네이밍 및 Password Lifecycle 관리
- ✅ PSC Global Access 검증 및 Cross-Region 연결 테스트 (asia-northeast3 → us-west1)
- ✅ Multi-Region/Multi-Project PSC 스케일링 전략 수립 및 문서화
- ✅ Cloud SQL Database/User 자동 네이밍 구현 (`{project_name}_gamedb`, `{project_name}_app_user`)
- ✅ Password lifecycle 관리 구현 (ignore_changes로 수동 변경 허용)
- ✅ Terraform best practice 리서치 (password vs password_wo)
- ✅ DBeaver SSH 터널 연결 검증 완료
- 🔗 커밋: `314197e`, `381bda8`, `0d6c42f`

### 2025-12-02: Lock 파일 정리 및 PSC 설정 최적화
- ✅ Terraform Lock 파일 정리 및 일관성 확보 (37개 → 통합)
- ✅ IPv6 네트워킹 문제 해결 (stack_type: IPV4_ONLY)
- ✅ Cloud SQL PSC allowed_consumer_projects 자동 관리
- ✅ Private Service Connection IP 대역 사용자 지정 (/29)
- ✅ Cross-Project PSC 접근 구성 (mgmt → gcp-gcby)
- ✅ PSC Forwarding Rule Global Access 설정
- 🔗 커밋: `d127fe3`, `78ea66e`, `7c3fa3d`, `f660ac1`

### 2025-11-17: Memorystore Enterprise & Cloud SQL 개선
- ✅ `modules/memorystore-redis`가 Enterprise/Enterprise Plus tiers를 지원하도록 재작성 (google_redis_cluster + PSC 출력)
- ✅ `proj-default-templet` 및 jsj-game-m의 65-cache tfvars/README가 Enterprise 구성을 기본값으로 사용
- ✅ `modules/cloudsql-mysql` 읽기 복제본 로직을 손봐 failover target/네트워크 옵션 없이도 안정적으로 생성
- ✅ 10-network 레이어에서 Memorystore Enterprise용 Service Connection Policy를 자동으로 생성하고 관련 변수를 추가
- 🔗 커밋: `chore: Redis Enterprise 구성 적용`, `feat: Memorystore Enterprise 지원`, `feat: Memorystore PSC Service Connection Policy`, `fix: Cloud SQL replica private network fallback` 외

### 2025-11-11: Terragrunt 0.93 CLI 적용
- ✅ Terragrunt `run --all`/`--working-dir` 패턴으로 Jenkins 템플릿·환경별 Jenkinsfile 전면 교체
- ✅ `TG_NON_INTERACTIVE` 환경변수와 `--queue-include-dir` 기반 Plan/Apply 가이드 문서화 (README, Quick Reference, Quick Setup, Jenkins Pipeline)
- ✅ `run_terragrunt_stack.sh`와 Quick Setup 스크립트 예제가 새 CLI를 사용하도록 업데이트
- ✅ 2025-11-11 work_history 작성 및 문서 전반(run-all/--terragrunt) 레거시 표현 정리

### 2025-11-09: GCP 폴더 구조 자동화
- ✅ Cloud Logging API 타이밍 이슈 해결 (depends_on 명시적 참조)
- ✅ GCP 폴더 구조 생성 (games/kr-region/LIVE,Staging,GQ-dev)
- ✅ Bootstrap remote state로 폴더 ID 자동 참조
- ✅ 게임별 다른 리전 조합 지원 (for_each 3차원 구조)
- ✅ games/us-region 추가 (LIVE/Staging/GQ-dev 자동 생성)
- 🔗 커밋: `effe94a`, `2982d65`, `f6fdda8`, `56a7306`, `353aa10`

### 2025-11-07: jsj-game-j 환경 추가
- ✅ 신규 프로젝트 jsj-game-j 환경 생성 (9개 레이어 완료)
- ✅ 65-cache 레이어 zone 설정 이슈 해결
- ✅ naming 모듈 통합으로 중앙 집중식 관리
- 🔗 커밋: `696493a`, `c9dae19`, `a25b878`, `11c8667`

### 2025-11-06: Jenkins CI/CD 통합
- ✅ Jenkins Pipeline 자동화 구성
- ✅ Bootstrap Service Account 권한 설정
- ✅ Terragrunt in-place 실행으로 모듈 경로 문제 해결
- ✅ GCS remote_state 필수 파라미터 추가

### 2025-11-04: 인프라 템플릿 개선
- ✅ Private Service Connect 기본화
- ✅ proj-default-templet 변수 및 문서 정비
- ✅ 모듈별 README 업데이트

### 2025-11-03: Terragrunt 전환
- ✅ Terragrunt 기반 실행 구조로 전환
- ✅ 공통 변수 및 원격 상태 자동화
- ✅ WSL 환경 제약 문서화

### 2025-10-31: 모듈 안정화
- ✅ 네트워크/데이터베이스 모듈 개선
- ✅ jsj-game-d 환경 종료

### 2025-10-29: 레이어 확장
- ✅ Redis 캐싱 레이어 추가 (Session 6)
- ✅ Load Balancer 모듈/레이어 구현 (Session 5)
- ✅ 워크로드/데이터베이스 안정화 (Session 4)
- ✅ 관찰성 레이어 구현 (Session 3)

---

## 📊 통계

- **총 작업 일수**: 20일
- **세션 수**: 24개
- **주요 마일스톤**:
  - ✅ 초기 인프라 구축 (10/28)
  - ✅ 9개 레이어 완성 (10/29)
  - ✅ Terragrunt 전환 (11/03)
  - ✅ Jenkins CI/CD 통합 (11/06)
  - ✅ GCP 폴더 자동화 (11/09)
  - ✅ 문서 재구성 (11/12)
  - ✅ PSC 전면 적용 (12/02)
  - ✅ Cloud SQL 자동화 (12/03)
  - ✅ gcp-web3/gcp-gcby 인프라 배포 완료 (12/08)

## 🔙 돌아가기

- [CHANGELOG](../CHANGELOG.md)
- [문서 포털](../../README.md)
