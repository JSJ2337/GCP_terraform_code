# Memorystore Redis 모듈

Google Cloud Memorystore for Redis 인스턴스를 일관된 규칙으로 생성합니다. 기본값은 **STANDARD_HA** 티어를 사용하며 VPC 프라이빗 연결(Direct Peering)에 맞춰 구성되어 있습니다.

## 주요 기능
- Redis 6.x 기반 Memorystore 인스턴스 생성
- 고가용성(Standard HA) 및 대체 존 설정
- Enterprise 티어에서는 Replica/Read Endpoint 및 Shard 구성 지원
- VPC 프라이빗 연결 및 라벨 일괄 적용
- 주간 유지보수 창 지정 옵션

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

  # 읽기 복제본 2개 → Read Endpoint 주소 자동 제공
  replica_count = 2

  # Enterprise Sharded 구성 시 사용
  shard_count = 1

  connect_mode            = "PRIVATE_SERVICE_CONNECT"
  transit_encryption_mode = "SERVER_AUTHENTICATION"

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
| `replica_count` | Enterprise 티어 전용 읽기 복제본 수 (설정 시 Read Endpoint 노출) | `number` | `null` | ➖ |
| `shard_count` | Enterprise 티어 전용 샤드 수 (Sharded Enterprise 사용 시) | `number` | `null` | ➖ |
| `memory_size_gb` | 메모리 크기(GB) | `number` | `1` | ➖ |
| `redis_version` | Redis 버전 (`REDIS_3_2`, `REDIS_4_0`, `REDIS_5_0`, `REDIS_6_X`) | `string` | `"REDIS_6_X"` | ➖ |
| `authorized_network` | 접근 허용 VPC self link | `string` | n/a | ✅ |
| `connect_mode` | 연결 모드 (`DIRECT_PEERING`, `PRIVATE_SERVICE_CONNECT`) | `string` | `"DIRECT_PEERING"` | ➖ |
| `transit_encryption_mode` | 전송 암호화 (`DISABLED`, `SERVER_AUTHENTICATION`) | `string` | `"DISABLED"` | ➖ |
| `display_name` | 콘솔에 표시할 이름 | `string` | `""` | ➖ |
| `labels` | 리소스 라벨 | `map(string)` | `{}` | ➖ |
| `maintenance_window_day` | 유지보수 요일 (`MONDAY` 등) | `string` | `""` | ➖ |
| `maintenance_window_start_hour` | 유지보수 시작 시각(시간) | `number` | `null` | ➖ |
| `maintenance_window_start_minute` | 유지보수 시작 시각(분) | `number` | `null` | ➖ |

> 🔔 **Standard HA 주의**: `alternative_location_id`와 `authorized_network`는 필수입니다. 입력하지 않으면 배포가 실패합니다.

## 출력 값

| 이름 | 설명 |
|------|------|
| `instance_name` | 생성된 Redis 인스턴스 이름 |
| `host` | 연결용 호스트명 |
| `read_endpoint` | Enterprise 티어에서 replica_count ≥ 1일 때 제공되는 읽기 엔드포인트 |
| `port` | 연결 포트 (기본 6379) |
| `read_endpoint_port` | 읽기 엔드포인트 포트 |
| `region` | 배포 리전 |
| `alternative_location_id` | 대체 존 |
| `authorized_network` | 연결된 VPC self link |
| `tier` | 구성된 Memorystore 티어 |
| `replica_count` | Enterprise 티어에서 설정된 읽기 복제본 수 |

## 요구 사항
- Terraform >= 1.6
- Google Provider >= 5.30
- 해당 프로젝트에서 Memorystore API (`redis.googleapis.com`)가 활성화되어 있어야 합니다.

## 모범 사례
1. **VPC 피어링 선행**: `authorized_network`는 같은 프로젝트에 존재해야 하며, Shared VPC를 사용하는 경우 호스트 프로젝트에 권한이 있어야 합니다.
2. **모니터링 연동**: Cloud Monitoring 알림 정책으로 Redis 메모리/커넥션 사용량을 추적하세요.
3. **복원 전략**: STANDARD_HA는 자동 장애 조치를 제공하지만 백업/복원 기능이 없으므로 애플리케이션 레벨 복구 전략을 마련하세요.
