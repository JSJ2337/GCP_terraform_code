# Cloud SQL MySQL 모듈

이 모듈은 고가용성, 백업, 복제를 포함한 Google Cloud SQL MySQL 인스턴스를 생성하고 관리합니다.

## 기능

- **MySQL 인스턴스**: 다양한 버전 및 머신 타입 지원
- **고가용성**: Regional HA 구성 지원
- **자동 백업**: Point-in-time 복구 지원
- **Private IP**: VPC 통합을 통한 비공개 액세스
- **Private Service Connect (PSC)**: 서브넷 격리 및 Cross-Region 접근 지원
- **SSL 연결**: 보안 연결 강제
- **읽기 복제본**: 다중 리전 읽기 복제본 지원
- **데이터베이스 및 사용자**: 자동 생성 및 관리
- **패스워드 Lifecycle 관리**: 수동 변경 허용 (Terraform이 되돌리지 않음)
- **쿼리 인사이트**: 성능 모니터링
- **로깅**: 느린 쿼리 및 일반 쿼리 로깅, Cloud Logging 통합
- **자동 디스크 확장**: 용량 자동 증설

## 사용법

### 기본 MySQL 인스턴스

```hcl
module "mysql" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "my-mysql-instance"
  region        = "us-central1"

  tier = "db-n1-standard-1"

  databases = [
    {
      name = "myapp"
    }
  ]

  users = [
    {
      name     = "app_user"
      password = "secure-password-here"
    }
  ]
}
```

### Private IP를 사용하는 HA 구성

```hcl
module "mysql_ha" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "prod-mysql"
  region        = "us-central1"

  # HA 구성
  tier              = "db-n1-standard-2"
  availability_type = "REGIONAL"

  # Private IP 설정
  ipv4_enabled    = false
  private_network = "projects/my-project/global/networks/my-vpc"
  require_ssl     = true

  # 디스크 설정
  disk_size = 100
  disk_type = "PD_SSD"

  # 백업 설정
  backup_enabled                     = true
  backup_start_time                  = "03:00"
  point_in_time_recovery_enabled     = true
  transaction_log_retention_days     = 7
  backup_retained_count              = 7

  databases = [
    {
      name      = "production"
      charset   = "utf8mb4"
      collation = "utf8mb4_unicode_ci"
    }
  ]

  users = [
    {
      name     = "app_user"
      password = var.db_password
      host     = "%"
    }
  ]

  labels = {
    environment = "prod"
    managed_by  = "terraform"
  }
}
```

### 읽기 복제본이 있는 프로덕션 구성

```hcl
module "mysql_with_replicas" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "prod-mysql-master"
  region        = "us-central1"

  tier              = "db-n1-standard-4"
  availability_type = "REGIONAL"

  ipv4_enabled    = false
  private_network = "projects/my-project/global/networks/my-vpc"

  disk_size = 200
  disk_type = "PD_SSD"

  # 읽기 복제본
  read_replicas = {
    replica1 = {
      name   = "prod-mysql-read-1"
      region = "us-central1"
      tier   = "db-n1-standard-2"
    }
    replica2 = {
      name   = "prod-mysql-read-2"
      region = "us-east1"
      tier   = "db-n1-standard-2"
    }
  }

  # 데이터베이스 플래그 (커스텀 설정)
  database_flags = [
    {
      name  = "max_connections"
      value = "1000"
    }
  ]

  # 로깅 설정 (자동으로 database_flags에 추가됨)
  enable_slow_query_log = true
  slow_query_log_time   = 2
  enable_general_log    = false
  log_output            = "FILE"

  databases = [
    {
      name = "production"
    }
  ]

  users = [
    {
      name     = "app_user"
      password = var.db_password
    }
  ]
}
```

> **참고**: `database_flags`에 `log_output`을 직접 지정하면 모듈이 동일 플래그를 다시 추가하지 않아 중복 오류를 방지합니다.

**읽기 복제본 입력 필드**

- 필수: `name`, `region`, `tier`
- 선택: `failover_target`, `availability_type`(기본 ZONAL), `disk_size`, `disk_type`, `disk_autoresize`,
  `ipv4_enabled`, `private_network`, `database_flags`, `labels`

이를 통해 리전/머신 타입 뿐 아니라 복제본별 디스크, 네트워크를 세밀하게 재정의할 수 있습니다.

> **참고**: 읽기 복제본의 유지보수 창(maintenance_window)은 마스터 인스턴스의 설정을 자동으로 상속받으며, 복제본별로 개별 설정할 수 없습니다.

### 로깅 및 모니터링 설정

```hcl
module "mysql_with_logging" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "monitored-mysql"
  region        = "us-central1"

  tier = "db-n1-standard-2"

  # Query Insights 활성화
  query_insights_enabled  = true
  query_string_length     = 2048
  record_application_tags = true

  # 느린 쿼리 로깅 (성능 모니터링)
  enable_slow_query_log = true
  slow_query_log_time   = 2  # 2초 이상 걸리는 쿼리 로깅

  # 일반 쿼리 로깅 (디버깅 시에만 사용)
  enable_general_log = false  # 프로덕션에서는 false 권장

  # 로그 출력 방식 (FILE로 설정하면 Cloud Logging으로 전송)
  log_output = "FILE"

  # 추가 데이터베이스 플래그
  database_flags = [
    {
      name  = "max_connections"
      value = "500"
    }
  ]

  databases = [
    {
      name = "myapp"
    }
  ]

  users = [
    {
      name     = "app_user"
      password = var.db_password
    }
  ]

  labels = {
    environment = "prod"
    monitoring  = "enabled"
  }
}
```

### Private Service Connect (PSC) 구성

```hcl
module "mysql_psc" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "prod-mysql-psc"
  region        = "us-central1"

  tier              = "db-n1-standard-4"
  availability_type = "REGIONAL"

  # PSC 설정 (VPC Peering 대신 사용)
  ipv4_enabled = false
  enable_psc   = true

  # PSC 엔드포인트 생성을 허용할 프로젝트 목록
  # 현재 프로젝트는 자동으로 포함됨
  psc_allowed_consumer_projects = [
    "management-project-id",
    "other-project-id"
  ]

  databases = [
    {
      name = "production"
    }
  ]

  users = [
    {
      name     = "app_user"
      password = var.db_password
    }
  ]
}
```

**PSC 장점:**
- VPC Peering보다 더 강력한 네트워크 격리
- Cross-Project 접근 제어 (allowed_consumer_projects)
- Global Access 지원 (단일 PSC Endpoint로 모든 리전 접근 가능)
- 서브넷별 격리 가능

**PSC vs VPC Peering:**
| 기능 | PSC | VPC Peering |
|------|-----|-------------|
| 네트워크 격리 | 강력 (서브넷 레벨) | 약함 (VPC 레벨) |
| Cross-Project | 명시적 허용 필요 | 자동 |
| IP 대역 중복 | 허용 | 충돌 가능성 |
| 관리 복잡도 | 중간 | 낮음 |

### 공개 IP와 승인된 네트워크

```hcl
module "mysql_public" {
  source = "../../modules/cloudsql-mysql"

  project_id    = "my-project-id"
  instance_name = "dev-mysql"
  region        = "us-central1"

  tier = "db-f1-micro"

  # 공개 IP 사용
  ipv4_enabled = true
  require_ssl  = true

  # 승인된 네트워크
  authorized_networks = [
    {
      name = "office"
      cidr = "203.0.113.0/24"
    },
    {
      name = "vpn"
      cidr = "198.51.100.0/24"
    }
  ]

  databases = [
    {
      name = "devdb"
    }
  ]

  users = [
    {
      name     = "dev_user"
      password = "dev-password"
    }
  ]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | GCP 프로젝트 ID | `string` | - | yes |
| instance_name | Cloud SQL 인스턴스 이름 | `string` | - | yes |
| region | 인스턴스를 생성할 리전 | `string` | - | yes |
| database_version | MySQL 버전 | `string` | `"MYSQL_8_0"` | no |
| tier | 머신 타입 | `string` | `"db-n1-standard-1"` | no |
| availability_type | 가용성 타입 (ZONAL/REGIONAL) | `string` | `"ZONAL"` | no |
| disk_size | 디스크 크기 (GB) | `number` | `10` | no |
| disk_type | 디스크 타입 (PD_SSD/PD_HDD) | `string` | `"PD_SSD"` | no |
| disk_autoresize | 디스크 자동 확장 | `bool` | `true` | no |
| deletion_protection | 삭제 보호 | `bool` | `false` | no |
| backup_enabled | 자동 백업 활성화 | `bool` | `true` | no |
| backup_start_time | 백업 시작 시간 (HH:MM) | `string` | `"03:00"` | no |
| point_in_time_recovery_enabled | PITR 활성화 | `bool` | `true` | no |
| ipv4_enabled | 공개 IP 활성화 | `bool` | `false` | no |
| private_network | VPC 네트워크 셀프 링크 | `string` | `""` | no |
| require_ssl | SSL 연결 필수 | `bool` | `true` | no |
| query_insights_enabled | 쿼리 인사이트 활성화 | `bool` | `true` | no |
| enable_slow_query_log | 느린 쿼리 로깅 활성화 | `bool` | `true` | no |
| slow_query_log_time | 느린 쿼리 기준 시간 (초) | `number` | `2` | no |
| enable_general_log | 일반 쿼리 로깅 활성화 | `bool` | `false` | no |
| log_output | 로그 출력 방식 (FILE/TABLE) | `string` | `"FILE"` | no |
| databases | 생성할 데이터베이스 목록 | `list(object)` | `[]` | no |
| users | 생성할 사용자 목록 | `list(object)` | `[]` | no |
| read_replicas | 읽기 복제본 설정 (`name`, `region`, `tier` + 선택 필드로 디스크/네트워크/유지보수/플래그 지정) | `map(object)` | `{}` | no |
| labels | 리소스 레이블 | `map(string)` | `{}` | no |

## 출력 값

| 이름 | 설명 |
|------|------|
| instance_name | Cloud SQL 인스턴스 이름 |
| instance_connection_name | 인스턴스 연결 이름 |
| instance_ip_address | IP 주소 (private/public) |
| instance_private_ip_address | Private IP 주소 |
| database_names | 생성된 데이터베이스 이름 목록 |
| user_names | 생성된 사용자 이름 목록 |
| read_replica_connection_names | 읽기 복제본 연결 이름 |
| read_replica_ip_addresses | 읽기 복제본 IP 주소 (private/public) |

## 머신 타입 (Tier)

### 공유 코어
- `db-f1-micro` - 0.6 GB RAM (개발/테스트)
- `db-g1-small` - 1.7 GB RAM (소규모)

### 표준
- `db-n1-standard-1` - 1 vCPU, 3.75 GB RAM
- `db-n1-standard-2` - 2 vCPU, 7.5 GB RAM
- `db-n1-standard-4` - 4 vCPU, 15 GB RAM
- `db-n1-standard-8` - 8 vCPU, 30 GB RAM

### 고메모리
- `db-n1-highmem-2` - 2 vCPU, 13 GB RAM
- `db-n1-highmem-4` - 4 vCPU, 26 GB RAM
- `db-n1-highmem-8` - 8 vCPU, 52 GB RAM

## Private IP 설정

Private IP를 사용하려면 VPC 네트워크에 서비스 네트워킹이 활성화되어 있어야 합니다:

```bash
# 서비스 네트워킹 API 활성화
gcloud services enable servicenetworking.googleapis.com

# Private 서비스 연결 생성
gcloud compute addresses create google-managed-services-my-vpc \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=my-vpc

gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-my-vpc \
  --network=my-vpc
```

## 모범 사례

1. **네트워크 접근 제어**
   - 프로덕션에서는 항상 Private IP 사용
   - 공개 인터넷 노출 방지
   - **Private Service Connect (PSC) 사용 권장**
     - VPC Peering보다 강력한 격리
     - Cross-Project 접근 제어
     - Global Access로 Cross-Region 접근 지원
   - VPC Peering은 레거시 프로젝트에만 사용

2. **고가용성**
   - 프로덕션: `availability_type = "REGIONAL"`
   - 개발/테스트: `availability_type = "ZONAL"`

3. **백업 및 복구**
   - 자동 백업 활성화
   - Point-in-time 복구 활성화
   - 적절한 백업 보존 기간 설정

4. **SSL 연결**
   - 항상 SSL 연결 필수로 설정
   - 클라이언트에서 SSL 인증서 사용

5. **읽기 복제본**
   - 읽기 부하 분산을 위해 복제본 사용
   - 다른 리전에 배치하여 지연 시간 감소

6. **모니터링 및 로깅**
   - Query Insights 활성화 (쿼리 성능 분석)
   - 느린 쿼리 로깅 활성화 (`enable_slow_query_log = true`)
   - 적절한 느린 쿼리 기준 시간 설정 (기본 2초)
   - 로그는 FILE로 출력하여 Cloud Logging으로 전송
   - 일반 쿼리 로깅은 디버깅 시에만 활성화 (성능 영향)
   - Cloud Monitoring 알림 설정

7. **보안**
   - 프로덕션에서 필요 시 `deletion_protection = true`로 별도 활성화
   - 강력한 비밀번호 사용
   - 비밀번호는 Secret Manager에 저장
   - 패스워드 Lifecycle: 수동 변경 후 Terraform이 되돌리지 않음 (ignore_changes 적용)
   - 패스워드 분실 시 gcloud로 재설정 또는 리소스 재생성

## 보안 고려사항

1. **비밀번호 관리**

   **Lifecycle 관리 (중요!)**

   이 모듈은 사용자 비밀번호에 대해 `lifecycle { ignore_changes = [password] }`를 적용합니다:

   - ✅ Terraform이 초기 비밀번호 설정
   - ✅ 사용자가 GCP Console/gcloud로 비밀번호 변경 가능
   - ✅ Terraform apply 시 비밀번호 변경 무시 (되돌리지 않음)

   **비밀번호 분실 시 복구 방법:**

   ```bash
   # 방법 1: gcloud로 재설정 (권장 - 빠르고 간단)
   gcloud sql users set-password USER_NAME \
     --instance=INSTANCE_NAME \
     --password="NewPassword!" \
     --project=PROJECT_ID

   # 방법 2: Terraform 리소스 재생성
   terraform state rm 'module.mysql.google_sql_user.users["USER_NAME"]'
   gcloud sql users delete USER_NAME --instance=INSTANCE_NAME --project=PROJECT_ID
   terraform apply -target='module.mysql.google_sql_user.users["USER_NAME"]'
   ```

   **Secret Manager 사용 (권장):**
   ```hcl
   # Secret Manager 사용
   data "google_secret_manager_secret_version" "db_password" {
     secret = "db-password"
   }

   users = [
     {
       name     = "app_user"
       password = data.google_secret_manager_secret_version.db_password.secret_data
     }
   ]
   ```

   **주의사항:**
   - 현재 비밀번호는 Terraform State 파일에 저장됨
   - 프로덕션 환경에서는 Secret Manager 사용 권장
   - IAM Database Authentication으로 전환 고려

2. **네트워크 격리**
   - Private IP만 사용
   - VPC Service Controls 사용
   - Cloud SQL Proxy 사용

3. **액세스 제어**
   - IAM으로 데이터베이스 액세스 제어
   - 최소 권한 원칙 적용

## 연결 방법

### Cloud SQL Proxy 사용 (권장)
```bash
# Proxy 다운로드 및 실행
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
```

### Private IP로 직접 연결
```bash
mysql -h 10.x.x.x -u app_user -p myapp
```

### 애플리케이션에서 연결
```python
import mysql.connector

conn = mysql.connector.connect(
    host='10.x.x.x',  # Private IP
    user='app_user',
    password='password',
    database='myapp',
    ssl_ca='/path/to/server-ca.pem'
)
```

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30
- Google Beta Provider >= 5.30

## 필요한 권한

- `roles/cloudsql.admin` - Cloud SQL 관리
- `roles/compute.networkAdmin` - 네트워크 구성 (Private IP용)
- `roles/servicenetworking.networksAdmin` - 서비스 네트워킹 (Private IP용)

## 로깅 및 모니터링

### Cloud Logging 통합

이 모듈은 다음 로깅 기능을 자동으로 구성합니다:

1. **느린 쿼리 로그 (Slow Query Log)**
   - 지정된 시간보다 오래 걸리는 쿼리를 기록
   - 기본값: 2초 이상 걸리는 쿼리
   - 성능 문제 쿼리 식별에 유용
   ```hcl
   enable_slow_query_log = true
   slow_query_log_time   = 2  # 초 단위
   ```

2. **일반 쿼리 로그 (General Log)**
   - 모든 SQL 쿼리를 기록 (프로덕션에서는 비권장)
   - 디버깅 또는 감사 목적으로만 사용
   - 성능에 영향을 줄 수 있음
   ```hcl
   enable_general_log = false  # 기본값
   ```

3. **로그 출력 방식**
   - `FILE`: 로그 파일에 기록, Cloud Logging으로 자동 전송 (권장)
   - `TABLE`: MySQL 테이블에 기록
   ```hcl
   log_output = "FILE"  # 기본값
   ```

### Cloud Logging에서 로그 확인

```bash
# 느린 쿼리 로그 확인
gcloud logging read "resource.type=cloudsql_database AND
  logName=projects/PROJECT_ID/logs/cloudsql.googleapis.com%2Fmysql-slow.log" \
  --project=PROJECT_ID \
  --limit=50

# 일반 쿼리 로그 확인
gcloud logging read "resource.type=cloudsql_database AND
  logName=projects/PROJECT_ID/logs/cloudsql.googleapis.com%2Fmysql.log" \
  --project=PROJECT_ID \
  --limit=50

# 에러 로그 확인
gcloud logging read "resource.type=cloudsql_database AND
  logName=projects/PROJECT_ID/logs/cloudsql.googleapis.com%2Fmysql.err" \
  --project=PROJECT_ID \
  --limit=50
```

### Query Insights

Query Insights는 쿼리 성능을 분석하고 최적화 제안을 제공합니다:

- 실행 시간이 가장 긴 쿼리 식별
- 쿼리 실행 빈도 분석
- CPU 및 I/O 사용량 모니터링
- 인덱스 최적화 제안

GCP Console에서 확인:
```
Cloud SQL > 인스턴스 선택 > Query Insights
```

### 로깅 비용 최적화

1. **프로덕션**
   - 느린 쿼리 로그: ✅ 활성화
   - 일반 로그: ❌ 비활성화
   - Query Insights: ✅ 활성화

2. **개발/스테이징**
   - 느린 쿼리 로그: ✅ 활성화
   - 일반 로그: ⚠️ 필요시에만 활성화
   - Query Insights: ✅ 활성화

3. **디버깅**
   - 느린 쿼리 로그: ✅ 활성화
   - 일반 로그: ✅ 임시 활성화
   - Query Insights: ✅ 활성화

## 참고사항

- 인스턴스 생성에 5-10분 소요
- Private IP 사용 시 VPC 서비스 연결 필요
- PSC 사용 시 PSC Forwarding Rule 별도 생성 필요
- HA 구성은 비용이 약 2배
- 읽기 복제본은 비동기 복제 사용
- 디스크 크기는 증가만 가능 (감소 불가)
- deletion_protection 활성화 시 수동으로 비활성화 후 삭제 필요
- 로깅 변수는 자동으로 database_flags에 추가됨
- 일반 로그는 많은 양의 로그를 생성하므로 Cloud Logging 비용 증가 가능
- **패스워드 Lifecycle**: 사용자 비밀번호는 ignore_changes 적용되어 수동 변경 허용

## PSC (Private Service Connect) 설정 가이드

### PSC 아키텍처 이해

**PSC Forwarding Rule의 역할:**
- Cloud SQL Service Attachment에 연결
- Private IP 할당 (PSC 전용 subnet)
- Global Access 설정 시 모든 리전에서 접근 가능

**스케일링 패턴:**

| 시나리오 | 필요한 리소스 |
|---------|--------------|
| 같은 리전, 새 Cloud SQL | 새 PSC FR (같은 subnet, 다른 IP) |
| 다른 리전, 새 Cloud SQL | 새 Subnet + 새 PSC FR |
| 다른 리전, VM만 추가 | 없음 (Global Access 활용) |

**예시:**
```
# 프로젝트 gcby
- Cloud SQL: us-west1
- PSC Subnet: 10.250.20.0/24 (us-west1)
- PSC FR IP: 10.250.20.20
- Bastion: asia-northeast3
- 연결: Global Access로 Cross-Region 접근 ✅

# 프로젝트 game2 (같은 mgmt 프로젝트)
- Cloud SQL: us-west1
- PSC Subnet: 10.250.20.0/24 (공유)
- PSC FR IP: 10.250.20.21 (다른 IP)
- 연결: 동일한 방식으로 접근 ✅
```

### PSC 설정 요구사항

1. **모듈에서 PSC 활성화:**
   ```hcl
   module "mysql" {
     enable_psc = true
     psc_allowed_consumer_projects = [
       "management-project-id"  # mgmt 프로젝트 추가
     ]
   }
   ```

2. **PSC Forwarding Rule 생성 (별도):**
   - 10-network 레이어에서 PSC subnet 생성
   - management 프로젝트에서 PSC Forwarding Rule 생성
   - Global Access 활성화 (`allow_psc_global_access = true`)

3. **Private DNS 설정:**
   - Cloud DNS에 Private Zone 생성
   - `{instance-name}.{domain}.internal` A 레코드
   - PSC Forwarding Rule IP 매핑

### 연결 방법

**로컬 PC에서 접근 (DBeaver, MySQL Workbench 등):**
1. SSH 터널 설정 (Bastion Host 경유)
2. 접속 주소: `{instance-name}.{domain}.internal`
3. 포트: 3306

**GCE VM에서 직접 접근:**
```bash
mysql -h {instance-name}.{domain}.internal -u root -p
```

**Cloud SQL Proxy 사용:**
```bash
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
```
