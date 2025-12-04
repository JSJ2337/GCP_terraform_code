# Memorystore Redis 모듈

Google Cloud Memorystore for Redis 인스턴스를 일관된 규칙으로 생성합니다. 기본값은 **STANDARD_HA** 티어를 사용하며 VPC 프라이빗 연결(Direct Peering)에 맞춰 구성되어 있으며, **ENTERPRISE/ENTERPRISE_PLUS** 티어를 선택하면 PSC(Private Service Connect) 기반 Redis Cluster도 프로비저닝할 수 있습니다.

## 주요 기능
- Redis 6.x 기반 STANDARD_HA/BASIC 인스턴스 생성 (Direct Peering)
- Enterprise/Enterprise Plus 클러스터 생성 (PSC, 다중 샤드/복제본)
- 고가용성(Standard HA) 및 대체 존 설정
- 유지보수 창, 라벨, 네트워크 설정 일괄 관리

## 사용 예시

```hcl
module "cache" {
  source = "../../modules/memorystore-redis"

  project_id             = "my-project"
  instance_name          = "myproj-prod-redis"
  region                 = "us-central1-a"  # IMPORTANT: Must be a ZONE, not a region
  alternative_location_id = "us-central1-b" # For STANDARD_HA tier
  memory_size_gb         = 4
  authorized_network     = "projects/my-project/global/networks/myproj-prod-vpc"

  labels = {
    environment = "prod"
    service     = "game"
  }
}
```

### Enterprise + Read Replica 구성

```hcl
module "cache_enterprise" {
  source = "../../modules/memorystore-redis"

  project_id        = "my-project"
  instance_name     = "myproj-prod-redis-ent"
  region            = "asia-northeast3-a"
  tier              = "ENTERPRISE"
  memory_size_gb    = 12
  authorized_network = "projects/my-project/global/networks/myproj-prod-vpc"

  # REQUIRED: Enterprise tier는 replica_count / shard_count를 지정해야 PSC endpoint가 생성됩니다.
  replica_count = 2

  shard_count = 1  # 샤딩 활성화

  connect_mode            = "PRIVATE_SERVICE_CONNECT"
  enterprise_transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"
  enterprise_node_type              = "REDIS_STANDARD_SMALL"

  labels = {
    environment = "prod"
    workload    = "ranking-service"
  }
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| `project_id` | 프로젝트 ID | `string` | n/a | ✅ |
| `instance_name` | Memorystore 인스턴스 이름 | `string` | n/a | ✅ |
| `region` | **기본 존** (예: `us-central1-a`) ⚠️ **ZONE 필수, region 아님** | `string` | n/a | ✅ |
| `alternative_location_id` | Standard HA용 대체 존 (예: `us-central1-b`) | `string` | `""` | ➖ |
| `tier` | Memorystore 티어 (`STANDARD_HA`, `BASIC`, `ENTERPRISE`, `ENTERPRISE_PLUS`) | `string` | `"STANDARD_HA"` | ➖ |
| `replica_count` | Enterprise 티어 전용 읽기 복제본 수 (필수) | `number` | `null` | ➖ |
| `shard_count` | Enterprise 티어 전용 샤드 수 (필수) | `number` | `null` | ➖ |
| `memory_size_gb` | 메모리 크기(GB) | `number` | `1` | ➖ |
| `redis_version` | Redis 버전 (`REDIS_3_2`, `REDIS_4_0`, `REDIS_5_0`, `REDIS_6_X`) | `string` | `"REDIS_6_X"` | ➖ |
| `authorized_network` | 접근 허용 VPC self link (Enterprise도 동일 입력을 PSC 네트워크로 사용) | `string` | n/a | ✅ |
| `connect_mode` | 연결 모드 (`DIRECT_PEERING`, `PRIVATE_SERVICE_CONNECT`) — Enterprise는 PSC 필수 | `string` | `"DIRECT_PEERING"` | ➖ |
| `transit_encryption_mode` | STANDARD/BASIC용 전송 암호화 (`DISABLED`/`SERVER_AUTHENTICATION`) | `string` | `"DISABLED"` | ➖ |
| `enterprise_node_type` | Enterprise 노드 타입 (`REDIS_STANDARD_SMALL`, `REDIS_HIGHMEM_MEDIUM` 등) | `string` | `"REDIS_STANDARD_SMALL"` | ➖ |
| `enterprise_authorization_mode` | Enterprise 인증 모드 (`AUTH_MODE_IAM_AUTH`, `AUTH_MODE_DISABLED`) | `string` | `"AUTH_MODE_DISABLED"` | ➖ |
| `enterprise_transit_encryption_mode` | Enterprise 전송 암호화 (`TRANSIT_ENCRYPTION_MODE_*`) | `string` | `"TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"` | ➖ |
| `enterprise_redis_configs` | Enterprise 클러스터에 적용할 Redis 설정 맵 | `map(string)` | `{}` | ➖ |
| `display_name` | 콘솔에 표시할 이름 | `string` | `""` | ➖ |
| `labels` | 리소스 라벨 | `map(string)` | `{}` | ➖ |
| `maintenance_window_day` | 유지보수 요일 (`MONDAY` 등 대문자) | `string` | `""` | ➖ |
| `maintenance_window_start_hour` | 유지보수 시작 시각(시간) | `number` | `null` | ➖ |
| `maintenance_window_start_minute` | 유지보수 시작 시각(분) | `number` | `null` | ➖ |

> 🔔 **Standard HA**: `alternative_location_id`와 `authorized_network`가 비어 있으면 배포가 실패합니다.  
> 🔔 **Enterprise**: `replica_count`, `shard_count`, `connect_mode = "PRIVATE_SERVICE_CONNECT"`를 반드시 지정해야 PSC 엔드포인트가 생성됩니다.

## 출력 값

| 이름 | 설명 |
|------|------|
| `instance_name` | 생성된 Redis 인스턴스 이름 |
| `host` | STANDARD/BASIC 티어에서 제공되는 기본 엔드포인트 |
| `read_endpoint` | STANDARD/BASIC 티어에서 제공되는 읽기 엔드포인트 (Enterprise는 PSC 사용) |
| `port` | 연결 포트 (PSC도 기본 6379) |
| `read_endpoint_port` | 읽기 엔드포인트 포트 |
| `region` | 배포 리전 또는 존 |
| `alternative_location_id` | STANDARD_HA 대체 존 |
| `authorized_network` | 사용한 VPC self link |
| `tier` | 구성된 Memorystore 티어 |
| `replica_count` | Enterprise 티어에서 설정된 읽기 복제본 수 |
| `psc_connections` | Enterprise PSC 연결 메타데이터 (forwarding rule, IP 등) |

## 요구 사항
- Terraform >= 1.6
- Google Provider >= 5.30
- 해당 프로젝트에서 Memorystore API (`redis.googleapis.com`)가 활성화되어 있어야 합니다.

## 모범 사례
1. **VPC 피어링 선행**: `authorized_network`는 같은 프로젝트에 존재해야 하며, Shared VPC를 사용하는 경우 호스트 프로젝트에 권한이 있어야 합니다.
2. **모니터링 연동**: Cloud Monitoring 알림 정책으로 Redis 메모리/커넥션 사용량을 추적하세요.
3. **복원 전략**: STANDARD_HA는 자동 장애 조치를 제공하지만 백업/복원 기능이 없으므로 애플리케이션 레벨 복구 전략을 마련하세요. Enterprise는 PSC 전용이므로 사전에 Service Connection Policy/Authorized networks를 준비해야 합니다.

## PSC (Private Service Connect) 설정 가이드

### 아키텍처 개요

Enterprise Redis Cluster는 PSC를 통해 네트워크 격리된 연결을 제공합니다.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Cross-Project Redis PSC Architecture                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────┐    ┌────────────────────────────┐          │
│  │     Game Project (gcby)    │    │    Management Project      │          │
│  │                            │    │                            │          │
│  │  ┌──────────────────────┐  │    │  ┌──────────────────────┐  │          │
│  │  │    gcby-live-vpc     │  │    │  │     mgmt-vpc         │  │          │
│  │  │                      │  │    │  │                      │  │          │
│  │  │  ┌────────────────┐  │  │    │  │  ┌────────────────┐  │  │          │
│  │  │  │ Redis Cluster  │  │  │    │  │  │  Bastion Host  │  │  │          │
│  │  │  │ (Enterprise)   │  │  │    │  │  │  10.250.20.10  │  │  │          │
│  │  │  │                │  │  │    │  │  └────────────────┘  │  │          │
│  │  │  │ Service        │  │  │    │  │         │            │  │          │
│  │  │  │ Attachment     │──┼──┼────┼──┼─────────┼────────────┼──┼──┐       │
│  │  │  │ (Discovery)    │  │  │    │  │         │            │  │  │       │
│  │  │  └────────────────┘  │  │    │  │         ▼            │  │  │       │
│  │  │                      │  │    │  │  ┌────────────────┐  │  │  │       │
│  │  │  ┌────────────────┐  │  │    │  │  │ PSC Endpoint   │  │  │  │       │
│  │  │  │ Service        │  │  │    │  │  │ 10.250.20.101  │◄─┼──┼──┘       │
│  │  │  │ Attachment     │──┼──┼────┼──┼──│ (Discovery)    │  │  │          │
│  │  │  │ (Shard)        │  │  │    │  │  └────────────────┘  │  │          │
│  │  │  └────────────────┘  │  │    │  │                      │  │          │
│  │  │                      │  │    │  │  ┌────────────────┐  │  │          │
│  │  └──────────────────────┘  │    │  │  │ PSC Endpoint   │◄─┼──┼──┐       │
│  │                            │    │  │  │ 10.250.20.102  │  │  │  │       │
│  └────────────────────────────┘    │  │  │ (Shard)        │  │  │  │       │
│                                    │  │  └────────────────┘  │  │  │       │
│                                    │  │                      │  │  │       │
│                                    │  └──────────────────────┘  │  │       │
│                                    │                            │  │       │
│                                    └────────────────────────────┘  │       │
│                                                                    │       │
│  Redis Cluster에서 2개의 Service Attachment가 생성됨:              │       │
│  • Discovery Endpoint (클러스터 토폴로지) ─────────────────────────┘       │
│  • Shard Endpoint (데이터 액세스) ──────────────────────────────────────────┘
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### PSC 연결 설정 단계

1. **모듈에서 Enterprise + PSC 활성화:**
   ```hcl
   module "redis_enterprise" {
     source = "../../modules/memorystore-redis"

     project_id     = "game-project"
     instance_name  = "gcby-live-redis"
     region         = "asia-northeast3-a"
     tier           = "ENTERPRISE"
     memory_size_gb = 12

     # PSC 필수 설정
     replica_count = 2
     shard_count   = 1
     connect_mode  = "PRIVATE_SERVICE_CONNECT"

     # TLS 암호화 (PSC 사용 시 권장)
     enterprise_transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"

     authorized_network = "projects/game-project/global/networks/gcby-live-vpc"
   }
   ```

2. **PSC Forwarding Rule 생성 (별도 리소스):**
   ```hcl
   # Redis Cluster는 2개의 Service Attachment를 생성함
   # Discovery Endpoint + Shard Endpoint

   resource "google_compute_forwarding_rule" "redis_psc_discovery" {
     project               = "mgmt-project"
     name                  = "gcby-live-redis-psc-discovery"
     region                = "asia-northeast3"
     network               = "projects/mgmt-project/global/networks/mgmt-vpc"
     subnetwork            = "projects/mgmt-project/regions/asia-northeast3/subnetworks/mgmt-psc-subnet"
     ip_address            = "10.250.20.101"
     load_balancing_scheme = ""
     target                = module.redis_enterprise.psc_connections[0].service_attachment

     # Cross-Region 접근을 위해 Global Access 활성화
     allow_psc_global_access = true
   }

   resource "google_compute_forwarding_rule" "redis_psc_shard" {
     project               = "mgmt-project"
     name                  = "gcby-live-redis-psc-shard"
     region                = "asia-northeast3"
     network               = "projects/mgmt-project/global/networks/mgmt-vpc"
     subnetwork            = "projects/mgmt-project/regions/asia-northeast3/subnetworks/mgmt-psc-subnet"
     ip_address            = "10.250.20.102"
     load_balancing_scheme = ""
     target                = module.redis_enterprise.psc_connections[1].service_attachment

     allow_psc_global_access = true
   }
   ```

3. **Private DNS 레코드 생성:**
   ```hcl
   # DNS A 레코드로 PSC Endpoint IP 매핑
   module "dns" {
     source = "../../modules/cloud-dns"

     project_id  = "mgmt-project"
     zone_name   = "internal-zone"
     dns_name    = "delabsgames.internal."
     visibility  = "private"

     dns_records = [
       {
         name    = "gcby-live-cache"
         type    = "A"
         ttl     = 300
         rrdatas = ["10.250.20.101"]  # Discovery Endpoint
       }
     ]
   }
   ```

### TLS 연결 테스트

Enterprise Redis Cluster는 TLS가 활성화되면 TLS 연결만 허용합니다:

```bash
# TLS 연결 테스트 (--tls --insecure는 자체 서명 인증서 허용)
redis-cli -h gcby-live-cache.delabsgames.internal -p 6379 --tls --insecure PING

# 또는 IP로 직접 연결
redis-cli -h 10.250.20.101 -p 6379 --tls --insecure PING
```

**redis-cli TLS 빌드 (필요 시):**
```bash
# RHEL/Rocky Linux
sudo dnf install -y gcc make openssl-devel
wget https://download.redis.io/releases/redis-7.2.6.tar.gz
tar xzf redis-7.2.6.tar.gz
cd redis-7.2.6
make redis-cli BUILD_TLS=yes
./src/redis-cli -h 10.250.20.101 -p 6379 --tls --insecure PING
```

### PSC vs Direct Peering 비교

| 기능 | PSC (Enterprise) | Direct Peering (Standard) |
|------|------------------|---------------------------|
| **네트워크 격리** | 강력 (엔드포인트별 격리) | 약함 (VPC 피어링) |
| **Cross-Project** | 지원 (명시적 허용) | 제한적 |
| **Cross-Region** | Global Access로 지원 | 불가 |
| **IP 대역 충돌** | 없음 (독립 IP) | 가능 |
| **TLS** | 기본 지원 | 선택적 |
| **비용** | 높음 (Enterprise) | 낮음 (Standard) |

### 필요한 권한

- `roles/redis.admin` - Redis 인스턴스 생성/관리
- `roles/compute.networkAdmin` - PSC Forwarding Rule 생성
- `roles/servicenetworking.networksAdmin` - Service Connection Policy
