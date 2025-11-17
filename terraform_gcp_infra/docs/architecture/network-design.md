# 네트워크 설계

GCP VPC 네트워크의 DMZ/Private/DB 3-Tier 아키텍처 설계입니다.

## 아키텍처 개요

```text
Internet
   ↓
Load Balancer (Public IP)
   ↓
┌─────────────────────────────────────────┐
│           DMZ Subnet (10.0.1.0/24)      │
│  - Web VMs (Public facing)              │
│  - Cloud NAT (Outbound only)            │
└──────────────┬──────────────────────────┘
               ↓ (Internal Only)
┌─────────────────────────────────────────┐
│         Private Subnet (10.0.2.0/24)    │
│  - Application VMs                      │
│  - Redis Cache (Private IP)             │
│  - No Public IP                         │
└──────────────┬──────────────────────────┘
               ↓ (Private IP Only)
┌─────────────────────────────────────────┐
│           DB Subnet (10.0.3.0/24)       │
│  - Cloud SQL MySQL (Private IP)         │
│  - Private Service Connect              │
│  - Complete Isolation                   │
└─────────────────────────────────────────┘
```

## 서브넷 설계

### 1. DMZ Subnet (Public Tier)

**목적**: 외부 트래픽 처리

**특징**:

- CIDR: `10.0.1.0/24`
- VM: Public IP 없음 (LB 경유)
- Outbound: Cloud NAT 사용
- 용도: Web 서버, API Gateway

**보안**:

- LB에서만 Inbound 허용
- Cloud NAT로 Outbound 제한
- 방화벽 규칙으로 포트 제한

### 2. Private Subnet (Application Tier)

**목적**: 내부 비즈니스 로직 처리

**특징**:

- CIDR: `10.0.2.0/24`
- VM: Public IP 없음
- Outbound: NAT 미사용 (필요 시 DMZ 경유)
- 용도: App 서버, Worker, Redis

**보안**:

- DMZ에서만 접근 가능
- 외부 노출 없음
- Internal Load Balancer 사용

### 3. DB Subnet (Data Tier)

**목적**: 데이터 저장 및 관리

**특징**:

- CIDR: `10.0.3.0/24`
- Cloud SQL: Private IP only
- Private Service Connect 연결
- 용도: MySQL, Redis (선택)

**보안**:

- Private에서만 접근 가능
- 외부 IP 없음
- PSC로 완전 격리

## Private Service Connect

### 설정 예시

```hcl
# 10-network/main.tf
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network = google_compute_network.vpc.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.private_ip_alloc.name
  ]
}
```

### 효과

- Cloud SQL이 VPC 내부 IP 사용
- 외부 노출 없음
- 서브넷 간 Private IP 통신

## Cloud NAT (DMZ 전용)

### 설정 절차

```hcl
resource "google_compute_router_nat" "nat" {
  name   = "nat-gateway"
  router = google_compute_router.router.name
  region = var.region_primary

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.dmz.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
```

### 특징

- DMZ 서브넷만 NAT 적용
- Private/DB 서브넷은 NAT 없음
- Outbound 트래픽만 허용

## 방화벽 규칙

### DMZ 규칙

```hcl
# LB → DMZ (HTTP/HTTPS)
ingress {
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]  # LB
  protocol      = "tcp"
  ports         = ["80", "443"]
}

# IAP → DMZ (SSH)
ingress {
  source_ranges = ["35.235.240.0/20"]
  protocol      = "tcp"
  ports         = ["22"]
}
```

### Private 규칙

```hcl
# DMZ → Private (App)
ingress {
  source_ranges = ["10.0.1.0/24"]  # DMZ
  protocol      = "tcp"
  ports         = ["8080", "9090"]
}

# Private → Redis
ingress {
  source_ranges = ["10.0.2.0/24"]  # Private
  protocol      = "tcp"
  ports         = ["6379"]
}
```

### DB 규칙

```hcl
# Private → DB (MySQL)
ingress {
  source_ranges = ["10.0.2.0/24"]  # Private only
  protocol      = "tcp"
  ports         = ["3306"]
}
```

## 트래픽 흐름

### 외부 → 내부 (Ingress)

```text
User → Internet → LB (Public IP)
  → DMZ (10.0.1.x) → Private (10.0.2.x)
  → DB (10.0.3.x)
```

### 내부 → 외부 (Egress)

```text
DMZ (10.0.1.x) → Cloud NAT → Internet
Private/DB → ❌ (차단)
```

### 내부 통신

```text
DMZ ↔ Private: 직접 통신 (10.0.0.0/16)
Private ↔ DB: 직접 통신 (Private IP)
DMZ ↔ DB: 차단 (방화벽)
```

## VPC Flow Logs

### 활성화

```hcl
resource "google_compute_subnetwork" "dmz" {
  # ...
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
```

### 확인

```bash
gcloud logging read \
    "resource.type=gce_subnetwork" \
    --project=jsj-game-k \
    --limit=50
```

## IP 주소 계획

### CIDR 할당

```text
VPC:     10.0.0.0/16     (65,536 IPs)
├─ DMZ:      10.0.1.0/24  (256 IPs)
├─ Private:  10.0.2.0/24  (256 IPs)
├─ DB:       10.0.3.0/24  (256 IPs)
└─ Reserved: 10.0.4.0/22  (1,024 IPs, 확장용)
```

### IP 사용량

- **DMZ**: 10-50 VMs (80% 여유)
- **Private**: 20-100 VMs (60% 여유)
- **DB**: 5-10 instances (95% 여유)

## 고가용성 (HA)

### Multi-Zone 배포

```hcl
# VM을 여러 Zone에 분산
zones = [
  "asia-northeast3-a",
  "asia-northeast3-b",
  "asia-northeast3-c"
]
```

### Load Balancer

- Health Check로 장애 감지
- 자동 Failover
- Cross-region 지원 (선택)

### Cloud SQL

- Regional HA (Multi-AZ)
- 자동 Failover
- Read Replica (선택)

## 확장 전략

### 수평 확장 (Scale Out)

```text
1. Instance Group 크기 조정
2. Auto-scaling 정책 추가
3. LB Backend 자동 등록
```

### 수직 확장 (Scale Up)

```text
1. VM Machine Type 변경
2. DB Tier 업그레이드
3. Redis 메모리 증설
```

### 네트워크 확장

```text
1. 새 서브넷 추가 (10.0.4.0/24)
2. VPC Peering (다른 VPC)
3. Cloud VPN/Interconnect (On-premise)
```

## 보안 체크리스트

- [ ] DMZ만 Cloud NAT 사용
- [ ] Private/DB는 Public IP 없음
- [ ] PSC로 DB 격리
- [ ] 방화벽 규칙 최소 권한
- [ ] VPC Flow Logs 활성화
- [ ] IAP로 SSH 접근
- [ ] LB에 Cloud Armor 적용 (DDoS)
- [ ] SSL/TLS 인증서 적용

## 참고 자료

- [전체 아키텍처](./overview.md)
- [network-dedicated-vpc 모듈](../../modules/network-dedicated-vpc/README.md)
- [네트워크 문제 해결](../troubleshooting/network-issues.md)
