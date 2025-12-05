# Terraform GCP 인프라 아키텍처

이 문서는 Terraform 코드의 구조와 동작 방식을 시각적으로 설명합니다.

## 📋 목차

1. [전체 시스템 구조](#1-전체-시스템-구조)
2. [State 관리 아키텍처](#2-state-관리-아키텍처)
3. [배포 순서 및 의존성](#3-배포-순서-및-의존성)
4. [모듈 구조](#4-모듈-구조)
5. [실제 GCP 리소스 구조](#5-실제-gcp-리소스-구조)
6. [네트워크 아키텍처](#6-네트워크-아키텍처)

---

## 1. 전체 시스템 구조

```mermaid
%%{init: {'theme': 'default'}}%%
graph TB
    subgraph Bootstrap["Bootstrap (중앙 관리)"]
        B[bootstrap/]
        B_PROJ[jsj-system-mgmt<br/>관리용 프로젝트]
        B_BUCKET[jsj-terraform-state-prod<br/>중앙 State 버킷]
        B --> B_PROJ
        B_PROJ --> B_BUCKET
    end

    subgraph Modules["재사용 가능한 모듈"]
        M1[gcs-root]
        M2[gcs-bucket]
        M3[project-base]
        M4[network-dedicated-vpc]
        M5[iam]
        M6[observability]
        M7[gce-vmset]
        M8[cloudsql-mysql]
        M9[load-balancer]
        M10[memorystore-redis]
    end

    subgraph Layers["환경별 배포 레이어"]
        E0[00-project<br/>프로젝트]
        E1[10-network<br/>네트워크]
        E2[20-storage<br/>스토리지]
        E3[30-security<br/>보안/IAM]
        E4[40-observability<br/>관찰성]
        E5[50-workloads<br/>워크로드]
        E6[60-database<br/>데이터베이스]
        E7[65-cache<br/>캐시]
        E8[70-loadbalancer<br/>로드밸런서]
    end

    B_BUCKET -.State 저장.-> E0
    B_BUCKET -.State 저장.-> E1
    B_BUCKET -.State 저장.-> E2
    B_BUCKET -.State 저장.-> E3
    B_BUCKET -.State 저장.-> E4
    B_BUCKET -.State 저장.-> E5
    B_BUCKET -.State 저장.-> E6
    B_BUCKET -.State 저장.-> E7
    B_BUCKET -.State 저장.-> E8

    E0 --> M3
    E1 --> M4
    E2 --> M1
    E3 --> M5
    E4 --> M6
    E5 --> M7
    E6 --> M8
    E7 --> M10
    E8 --> M9

    style Bootstrap fill:#e1f5ff
    style Modules fill:#ffffff
    style Layers fill:#ffffff
    style B fill:#e1f5ff
    style B_BUCKET fill:#fff3cd
    style E0 fill:#d4edda
    style E1 fill:#d4edda
    style E2 fill:#d4edda
    style E3 fill:#d4edda
    style E4 fill:#d4edda
    style E5 fill:#d4edda
    style E6 fill:#d4edda
    style E7 fill:#d4edda
    style E8 fill:#d4edda
```

**설명**:

- **Bootstrap**: 최우선 배포. 중앙 State 관리 인프라
- **Modules**: 재사용 가능한 Terraform 모듈 (9개)
- **Environments**: 실제 배포 레이어 (8개)
- **State 관리**: 모든 레이어의 State는 중앙 버킷에 저장

---

## 2. State 관리 아키텍처

```mermaid
%%{init: {'theme': 'default'}}%%
graph LR
    subgraph LocalEnv["로컬 개발 환경"]
        DEV[개발자 PC]
    end

    subgraph BootstrapProj["Bootstrap Project (jsj-system-mgmt)"]
        BUCKET[GCS Bucket<br/>jsj-terraform-state-prod]

        subgraph StateFiles["State 파일 구조"]
            S1[proj-default-templet/<br/>00-project/default.tfstate]
            S2[proj-default-templet/<br/>10-network/default.tfstate]
            S3[proj-default-templet/<br/>20-storage/default.tfstate]
            S4[proj-default-templet/<br/>30-security/default.tfstate]
            S5[proj-default-templet/<br/>40-observability/default.tfstate]
            S6[proj-default-templet/<br/>50-workloads/default.tfstate]
            S7[proj-default-templet/<br/>60-database/default.tfstate]
            S8[proj-default-templet/<br/>65-cache/default.tfstate]
            S9[proj-default-templet/<br/>70-loadbalancer/default.tfstate]
        end
    end

    DEV -->|terraform init| BUCKET
    DEV -->|terraform apply| BUCKET
    BUCKET --> S1
    BUCKET --> S2
    BUCKET --> S3
    BUCKET --> S4
    BUCKET --> S5
    BUCKET --> S6
    BUCKET --> S7
    BUCKET --> S8
    BUCKET --> S9
    BUCKET --> S8

    style LocalEnv fill:#e1f5ff
    style BootstrapProj fill:#ffffff
    style StateFiles fill:#ffffff
    style BUCKET fill:#fff3cd
    style DEV fill:#e1f5ff
```

**특징**:

- ✅ **중앙 집중식**: 모든 State가 한 곳에서 관리
- ✅ **버전 관리**: 최근 10개 버전 보관
- ✅ **레이어별 분리**: 각 레이어는 독립적인 State 파일
- ✅ **자동 정리**: 30일 지난 버전 자동 삭제

---

## 3. 배포 순서 및 의존성

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#000000' }}}%%
graph TD
    START([시작]) --> B[0. Bootstrap 배포<br/>중앙 State 관리]

    B --> E0[1. 00-project<br/>GCP 프로젝트 생성]

    E0 --> E1[2. 10-network<br/>VPC, 서브넷, 방화벽]

    E1 --> PARALLEL{병렬 배포 가능}

    PARALLEL --> E2[3. 20-storage<br/>GCS 버킷]
    PARALLEL --> E3[4. 30-security<br/>IAM, 서비스 계정]
    PARALLEL --> E4[5. 40-observability<br/>로깅, 모니터링]

    E2 --> E5[6. 50-workloads<br/>VM 인스턴스]
    E3 --> E5
    E4 --> E5
    E1 --> E6[7. 60-database<br/>Cloud SQL]

    E5 --> E7[8. 65-cache<br/>Memorystore Redis]
    E6 --> E7
    E7 --> E8[9. 70-loadbalancer<br/>Load Balancer]

    E8 --> END([완료])

    style B fill:#e1f5ff
    style E0 fill:#d4edda
    style E1 fill:#d4edda
    style E2 fill:#fff3cd
    style E3 fill:#fff3cd
    style E4 fill:#fff3cd
    style E5 fill:#d4edda
    style E6 fill:#d4edda
    style E7 fill:#d4edda
    style E8 fill:#d4edda
    style PARALLEL fill:#ffeaa7
```

**의존성 설명**:

1. **Bootstrap**: 반드시 최우선 배포
2. **00-project**: 다른 모든 리소스의 기반
3. **10-network**: 데이터베이스 Private IP, VM 네트워킹에 필요
4. **병렬 배포**: 20-storage, 30-security, 40-observability는 병렬 배포 가능
5. **60-database**: 네트워크 구성 필요 (Private IP)
6. **65-cache**: 전용 VPC(10-network) 이후 배포, 애플리케이션이 의존하기 전 캐시 엔드포인트 준비
7. **70-loadbalancer**: VM 인스턴스(백엔드) 필요

---

## 4. 모듈 구조

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#000000' }}}%%
graph LR
    M1[project-base<br/>프로젝트 생성]
    M2[network-dedicated-vpc<br/>VPC 네트워킹]
    M3[gcs-root<br/>다중 버킷]
    M4[gcs-bucket<br/>단일 버킷]
    M5[iam<br/>IAM 관리]
    M6[observability<br/>모니터링/로깅]
    M7[gce-vmset<br/>VM 인스턴스]
    M8[cloudsql-mysql<br/>MySQL DB]
    M9[load-balancer<br/>Load Balancer]
    M10[memorystore-redis<br/>Redis 캐시]

    M3 -->|사용| M4

    style M1 fill:#e1f5ff,stroke:#333,stroke-width:2px
    style M2 fill:#d4edda,stroke:#333,stroke-width:2px
    style M3 fill:#fff3cd,stroke:#333,stroke-width:2px
    style M4 fill:#fff3cd,stroke:#333,stroke-width:2px
    style M5 fill:#ffeaa7,stroke:#333,stroke-width:2px
    style M6 fill:#dfe6e9,stroke:#333,stroke-width:2px
    style M7 fill:#fab1a0,stroke:#333,stroke-width:2px
    style M8 fill:#74b9ff,stroke:#333,stroke-width:2px
    style M9 fill:#a29bfe,stroke:#333,stroke-width:2px
    style M10 fill:#ffeaa7,stroke:#333,stroke-width:2px
```

**모듈 목록 및 주요 기능**:

<!-- markdownlint-disable MD013 -->
| 모듈 | 주요 기능 | 카테고리 |
|------|----------|---------|
| **project-base** | 프로젝트 생성, API 활성화, 예산 알림, 삭제 정책 | 프로젝트 관리 |
| **network-dedicated-vpc** | VPC, 서브넷, 방화벽, Cloud NAT, Cloud Router, Service Networking | 네트워킹 |
| **gcs-root** | 다중 버킷 관리, 공통 설정 중앙화 | 스토리지 |
| **gcs-bucket** | 단일 버킷 상세 설정, 수명주기, 암호화, IAM | 스토리지 |
| **iam** | IAM 바인딩, 서비스 계정 관리 | 보안 & IAM |
| **observability** | Cloud Logging 싱크, 모니터링 알림 | 관찰성 |
| **gce-vmset** | VM 인스턴스, Shielded VM, 메타데이터 | 컴퓨팅 |
| **cloudsql-mysql** | MySQL 인스턴스, HA, Private IP, 백업, 복제본 | 데이터베이스 |
| **memorystore-redis** | Redis 캐시, Standard HA/Enterprise 구성, 유지보수 창 | 캐시 |
| **load-balancer** | HTTP(S) LB, Internal LB, Health Check, SSL, CDN | 로드 밸런싱 |
<!-- markdownlint-enable MD013 -->

**모듈 설계 원칙**:

- ✅ **Provider 블록 없음**: 모듈 재사용성 향상
- ✅ **포괄적인 변수**: 유연한 구성
- ✅ **Optional 속성**: Terraform 1.6+ 활용
- ✅ **한글 문서화**: 모든 모듈 README 포함
- ✅ **독립적 실행**: 각 모듈은 독립적으로 사용 가능

---

## 5. 실제 GCP 리소스 구조

```mermaid
%%{init: {'theme': 'default'}}%%
graph TB
    subgraph GCP_Project["GCP Project"]
        subgraph Network_Layer["Network Layer"]
            VPC[VPC Network]
            SUBNET1[Subnet: web<br/>10.0.1.0/24]
            SUBNET2[Subnet: app<br/>10.0.2.0/24]
            SUBNET3[Subnet: db<br/>10.0.3.0/24]
            FW[Firewall Rules]
            NAT[Cloud NAT]
            ROUTER[Cloud Router]

            VPC --> SUBNET1
            VPC --> SUBNET2
            VPC --> SUBNET3
            VPC --> FW
            VPC --> ROUTER
            ROUTER --> NAT
        end

        subgraph Storage_Layer["Storage Layer"]
            GCS1[GCS: assets-bucket]
            GCS2[GCS: logs-bucket]
            GCS3[GCS: backups-bucket]
        end

        subgraph Compute_Layer["Compute Layer"]
            VM1[VM Instance 1<br/>web-server]
            VM2[VM Instance 2<br/>app-server]
            IG[Instance Group]

            VM1 --> SUBNET1
            VM2 --> SUBNET2
            IG --> VM1
            IG --> VM2
        end

        subgraph Database_Layer["Database Layer"]
            SQL[Cloud SQL MySQL<br/>Private IP]
            REPLICA[Read Replica<br/>Optional]

            SQL --> SUBNET3
            SQL -.복제.-> REPLICA
        end

        subgraph Cache_Layer["Cache Layer"]
            REDIS[Memorystore Redis<br/>Private IP]
        end

        REDIS --> SUBNET2

        subgraph LB_Layer["Load Balancer Layer"]
            LB[Load Balancer]
            HC[Health Check]
            BE[Backend Service]
            FW_RULE[Forwarding Rule]
            IP[Static IP]

            LB --> FW_RULE
            FW_RULE --> IP
            LB --> BE
            BE --> HC
            BE --> IG
        end

        subgraph Security_IAM["Security & IAM"]
            SA1[Service Account: web]
            SA2[Service Account: app]
            SA3[Service Account: db]
        end

        subgraph Observability_Layer["Observability"]
            LOG[Cloud Logging]
            MON[Cloud Monitoring]
            ALERT[Alert Policies]
        end
    end

    VM1 -.로그.-> LOG
    VM2 -.로그.-> LOG
    SQL -.로그.-> LOG
    REDIS -.모니터링.-> MON
    MON --> ALERT

    style GCP_Project fill:#ffffff
    style Network_Layer fill:#ffffff
    style Storage_Layer fill:#ffffff
    style Compute_Layer fill:#ffffff
    style Database_Layer fill:#ffffff
    style Cache_Layer fill:#ffffff
    style LB_Layer fill:#ffffff
    style Security_IAM fill:#ffffff
    style Observability_Layer fill:#ffffff
    style VPC fill:#d4edda
    style SQL fill:#74b9ff
    style REDIS fill:#ffeaa7
    style LB fill:#a29bfe
    style GCS1 fill:#fff3cd
    style GCS2 fill:#fff3cd
    style GCS3 fill:#fff3cd
```

**리소스 계층**:

1. **Network**: 모든 리소스의 기반
2. **Storage**: 독립적으로 관리
3. **Compute**: 네트워크에 의존
4. **Database**: Private IP로 VPC에 연결
5. **Cache**: Memorystore Redis로 저지연 세션/캐시 제공
6. **Load Balancer**: Compute 인스턴스를 백엔드로 사용
7. **Security**: 모든 리소스에 IAM 적용
8. **Observability**: 모든 리소스 모니터링

---

## 6. 네트워크 아키텍처

```mermaid
%%{init: {'theme': 'default'}}%%
graph LR
    subgraph Internet_Zone["인터넷"]
        USER[사용자]
        INTERNET[Internet]
    end

    subgraph GCP_VPC["GCP VPC (10.0.0.0/16)"]
        subgraph Public_Subnet["Public Subnet (10.0.1.0/24)"]
            LB[Load Balancer<br/>외부 IP]
        end

        subgraph Web_Subnet["Web Subnet (10.0.1.0/24)"]
            WEB1[Web VM 1<br/>10.0.1.10]
            WEB2[Web VM 2<br/>10.0.1.11]
        end

        subgraph App_Subnet["App Subnet (10.0.2.0/24)"]
            APP1[App VM 1<br/>10.0.2.10]
            APP2[App VM 2<br/>10.0.2.11]
            CACHE[Redis Cache<br/>Private IP<br/>10.0.2.25]
        end

        subgraph DB_Subnet["DB Subnet (10.0.3.0/24)"]
            DB[Cloud SQL<br/>Private IP<br/>10.0.3.5]
        end

        NAT_GW[Cloud NAT Gateway]
    end

    USER -->|HTTPS:443| INTERNET
    INTERNET -->|Public IP| LB
    LB -->|Health Check| WEB1
    LB -->|Health Check| WEB2
    LB -.Traffic.-> WEB1
    LB -.Traffic.-> WEB2

    WEB1 -->|Internal| APP1
    WEB2 -->|Internal| APP2

    APP1 -->|Private IP| DB
    APP2 -->|Private IP| DB
    APP1 -->|저지연 캐시| CACHE
    APP2 -->|저지연 캐시| CACHE

    WEB1 -.Outbound.-> NAT_GW
    WEB2 -.Outbound.-> NAT_GW
    APP1 -.Outbound.-> NAT_GW
    APP2 -.Outbound.-> NAT_GW
    NAT_GW -.-> INTERNET

    style Internet_Zone fill:#ffffff
    style GCP_VPC fill:#ffffff
    style Public_Subnet fill:#ffffff
    style Web_Subnet fill:#ffffff
    style App_Subnet fill:#ffffff
    style DB_Subnet fill:#ffffff
    style LB fill:#a29bfe
    style WEB1 fill:#fab1a0
    style WEB2 fill:#fab1a0
    style APP1 fill:#fab1a0
    style APP2 fill:#fab1a0
    style CACHE fill:#ffeaa7
    style DB fill:#74b9ff
    style NAT_GW fill:#d4edda
    style USER fill:#e1f5ff
```

**네트워크 흐름**:

1. **외부 → LB**: 사용자가 Public IP로 접근
2. **LB → Web**: Health Check 후 트래픽 분산
3. **Web → App**: 내부 통신
4. **App → Cache**: 동일 서브넷 Private IP로 Redis 접근
5. **App → DB**: Private IP로 DB 접근
6. **Internal → NAT**: 외부 API 호출 시 NAT 게이트웨이 사용

**보안**:

- ✅ Redis/DB는 Private IP만 사용 (외부 노출 없음)
- ✅ 방화벽 규칙으로 트래픽 제어
- ✅ VPC에는 Cloud SQL Private IP를 위한 Service Networking(Private Service Connect) 피어링이
      예약되어 데이터베이스 레이어가 별도 수동 작업 없이 바로 연결됩니다.
- ✅ Cloud NAT로 안전한 외부 통신

---

## 7. Terragrunt 실행 흐름

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#000000' }}}%%
sequenceDiagram
    participant Dev as 개발자
    participant TG as Terragrunt CLI
    participant GCS as State 버킷
    participant GCP as GCP API

    Dev->>TG: terragrunt init
    TG->>GCS: backend 초기화
    GCS-->>TG: State 로드

    Dev->>TG: terragrunt plan
    TG->>GCS: 현재 State 가져오기
    TG->>GCP: 실제 리소스 상태 확인
    GCP-->>TG: 현재 상태 반환
    TG-->>Dev: 변경 계획 표시

    Dev->>TG: terragrunt apply
    TG->>GCP: 리소스 생성/수정
    GCP-->>TG: 완료 확인
    TG->>GCS: 새로운 State 저장
    GCS-->>TG: State 저장 완료
    TG-->>Dev: 적용 완료

    Note over Dev,GCP: State는 항상 GCS에 중앙 관리됨
```

**실행 단계**:

1. **terragrunt init**: Backend 초기화, State 로드
2. **terragrunt plan**: 현재 상태와 목표 상태 비교
3. **terragrunt apply**: 실제 리소스 생성/수정
4. **State 저장**: 변경사항을 GCS에 저장

---

## 8. 모듈 재사용 예제

```mermaid
%%{init: {'theme': 'default'}}%%
graph TB
    subgraph MODULE_DEF["모듈 정의"]
        MODULE[cloudsql-mysql<br/>main.tf, variables.tf, outputs.tf]
    end

    subgraph PROD["환경 1: Production"]
        P_LAYER[60-database/]
        P_VARS["terraform.tfvars:<br/>tier=db-n1-standard-2<br/>HA enabled"]
        P_LAYER --> MODULE
        P_VARS -.설정.-> P_LAYER
    end

    subgraph DEV["환경 2: Development"]
        D_LAYER[60-database/]
        D_VARS["terraform.tfvars:<br/>tier=db-f1-micro<br/>HA disabled"]
        D_LAYER --> MODULE
        D_VARS -.설정.-> D_LAYER
    end

    subgraph STAGE["환경 3: Staging"]
        S_LAYER[60-database/]
        S_VARS["terraform.tfvars:<br/>tier=db-n1-standard-1<br/>HA enabled"]
        S_LAYER --> MODULE
        S_VARS -.설정.-> S_LAYER
    end

    style MODULE_DEF fill:#ffffff
    style PROD fill:#ffffff
    style DEV fill:#ffffff
    style STAGE fill:#ffffff
    style MODULE fill:#74b9ff
    style P_LAYER fill:#d4edda
    style D_LAYER fill:#fff3cd
    style S_LAYER fill:#ffeaa7
```

**재사용 패턴**:

- 하나의 모듈을 여러 환경에서 사용
- 환경별로 다른 변수 값 적용
- 코드 중복 없이 일관된 인프라 관리

---

## 9. 주요 설계 결정

### ✅ 중앙 State 관리

- **문제**: State 파일을 로컬에 보관하면 협업 어려움
- **해결**: GCS 버킷에 중앙 집중식 관리
- **장점**: 팀 협업, 버전 관리, 자동 백업

### ✅ 레이어 분리

- **문제**: 하나의 거대한 Terraform 구성은 관리 어려움
- **해결**: 8개 레이어로 분리 (00-70)
- **장점**: 독립적 배포, 빠른 Plan/Apply, 명확한 책임

### ✅ 모듈화

- **문제**: 환경마다 동일한 코드 반복
- **해결**: 재사용 가능한 모듈 9개 생성
- **장점**: 코드 재사용, 일관성, 유지보수 용이

### ✅ Provider 블록 제거

- **문제**: 모듈에 Provider 있으면 버전 충돌
- **해결**: 모듈에서 Provider 제거, 루트만 정의
- **장점**: 모듈 재사용성 향상, 버전 관리 단순화

---

## 10. 확장 로드맵

<!-- markdownlint-disable MD013 -->
```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryTextColor': '#000000' }}}%%
graph LR
    CURRENT[현재: 9개 모듈<br/>8개 레이어] --> PHASE1[Phase 1<br/>PostgreSQL<br/>Redis<br/>Secret Manager]

    PHASE1 --> PHASE2[Phase 2<br/>GKE<br/>Cloud Run<br/>Cloud Functions]

    PHASE2 --> PHASE3[Phase 3<br/>Multi-Region<br/>DR Setup<br/>Auto-scaling]

    PHASE3 --> PHASE4[Phase 4<br/>CI/CD<br/>Policy as Code<br/>Cost Optimization]

    style CURRENT fill:#d4edda
    style PHASE1 fill:#fff3cd
    style PHASE2 fill:#ffeaa7
    style PHASE3 fill:#fab1a0
    style PHASE4 fill:#a29bfe
```
<!-- markdownlint-enable MD013 -->

---

## 참고 자료

- [문서 포털](../README.md)
- [작업 이력](../changelog/work_history/README.md)
- [CHANGELOG](../changelog/CHANGELOG.md)
- [명령어 참조](../getting-started/quick-commands.md)

각 모듈의 상세 아키텍처는 해당 모듈 문서를 참조하세요:

- [cloudsql-mysql](../modules/cloudsql-mysql.md)
- [gce-vmset](../modules/gce-vmset.md)
- [gcs-bucket](../modules/gcs-bucket.md)
- [gcs-root](../modules/gcs-root.md)
- [iam](../modules/iam.md)
- [load-balancer](../modules/load-balancer.md)
- [memorystore-redis](../modules/memorystore-redis.md)
- [naming](../modules/naming.md)
- [network-dedicated-vpc](../modules/network-dedicated-vpc.md)
- [observability](../modules/observability.md)
- [project-base](../modules/project-base.md)
