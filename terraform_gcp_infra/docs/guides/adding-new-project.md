# 신규 프로젝트 추가 가이드

이 가이드는 **proj-default-templet** 템플릿과 **Bootstrap 일반화 구조**를 활용하여 새 프로젝트를 추가하는 방법을 설명합니다.

## 목차

1. [사전 준비](#사전-준비)
2. [프로젝트 폴더 구성](#프로젝트-폴더-구성)
3. [Bootstrap 통합](#bootstrap-통합)
4. [레이어별 설정](#레이어별-설정)
5. [배포 및 검증](#배포-및-검증)
6. [트러블슈팅](#트러블슈팅)

---

## 사전 준비

### 필요 정보

| 항목 | 예시 | 설명 |
|------|------|------|
| 프로젝트 이름 | `abc` | 짧은 식별자 (소문자, 숫자, 하이픈) |
| GCP Project ID | `gcp-abc` | GCP에서 생성할 프로젝트 ID |
| 환경 | `live` | live, staging, dev 등 |
| 리전 | `us-west1` | Primary 리전 |
| VPC CIDR | `10.20.0.0/16` | 프로젝트 VPC 대역 |
| Subnet CIDR | dmz: `10.20.10.0/24`<br>private: `10.20.11.0/24`<br>psc: `10.20.12.0/24` | 서브넷 대역 |
| PSC IP (mgmt) | cloudsql: `10.250.21.20`<br>redis: `10.250.21.101` | 관리 VPC의 PSC endpoint IP |
| VM IP | web01: `10.20.11.10` | VM 고정 IP (선택) |

### 확인 사항

```bash
# 1. GCP 인증 확인
gcloud auth application-default login

# 2. 조직/폴더 ID 확인
gcloud organizations list
gcloud resource-manager folders list --organization=YOUR_ORG_ID

# 3. Billing Account 확인
gcloud billing accounts list

# 4. 기존 프로젝트 구조 확인
ls -la environments/LIVE/
```

---

## 프로젝트 폴더 구성

### 1. 템플릿 복사

```bash
cd terraform_gcp_infra

# 템플릿을 새 프로젝트로 복사
cp -R proj-default-templet environments/LIVE/gcp-abc
```

### 2. root.hcl 수정

**파일**: `environments/LIVE/gcp-abc/root.hcl`

```hcl
locals {
  remote_state_bucket   = "jsj-terraform-state-prod"
  remote_state_project  = "delabs-gcp-mgmt"
  remote_state_location = "US"
  project_state_prefix  = "gcp-abc"    # ⚠️ 프로젝트별 고유값
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket   = local.remote_state_bucket
    project  = local.remote_state_project
    location = local.remote_state_location
    prefix   = "${local.project_state_prefix}/${path_relative_to_include()}"
  }
  skip_bucket_creation = true
}

inputs = {
  org_id          = "1034166519592"
  billing_account = "01B77E-0A986D-CB2651"
  region_primary  = "us-west1"
  region_backup   = "us-west2"
}
```

### 3. common.naming.tfvars 수정

**파일**: `environments/LIVE/gcp-abc/common.naming.tfvars`

```hcl
# 프로젝트 기본 정보
project_id     = "gcp-abc"
project_name   = "abc"
environment    = "live"
organization   = "delabs"
region_primary = "us-west1"
region_backup  = "us-west2"

# Bootstrap 폴더 설정
folder_product = "gcp-abc"
folder_region  = "us-west1"
folder_env     = "LIVE"

# 기본 라벨
base_labels = {
  managed-by  = "terraform"
  project     = "abc"
  team        = "product-team"
}

# 네트워크 설계 (중앙 관리)
network_config = {
  # Subnet CIDR
  subnets = {
    dmz     = "10.20.10.0/24"
    private = "10.20.11.0/24"
    psc     = "10.20.12.0/24"
  }

  # PSC Endpoint IP (abc VPC 내부)
  psc_endpoints = {
    cloudsql = "10.20.12.51"
    redis    = "10.20.12.101"
  }

  # VPC Peering (mgmt VPC)
  peering = {
    mgmt_project_id = "delabs-gcp-mgmt"
    mgmt_vpc_name   = "delabs-gcp-mgmt-vpc"
  }

  # VM Static IP
  vm_ips = {
    web01 = "10.20.11.10"
    web02 = "10.20.11.20"
  }
}

# 관리 프로젝트 정보
management_project_id = "delabs-gcp-mgmt"
```

---

## Bootstrap 통합

Bootstrap을 수정하여 새 프로젝트를 통합해야 합니다.

### 1. bootstrap/common.hcl - projects 추가

**파일**: `bootstrap/common.hcl`

```hcl
locals {
  # ... 기존 설정 ...

  projects = {
    gcby = {
      # 기존 gcby 설정 유지
      project_id   = "gcp-gcby"
      environment  = "live"
      vpc_name     = "gcby-live-vpc"
      network_url  = "projects/gcp-gcby/global/networks/gcby-live-vpc"
      psc_ips = {
        cloudsql = "10.250.20.20"
        redis    = "10.250.20.101"
      }
      vm_ips = {
        gs01 = "10.10.11.3"
        gs02 = "10.10.11.6"
      }
      database_path = "../../environments/LIVE/gcp-gcby/60-database"
      cache_path    = "../../environments/LIVE/gcp-gcby/65-cache"
    }

    # ⚠️ 새 프로젝트 추가
    abc = {
      project_id   = "gcp-abc"
      environment  = "live"
      vpc_name     = "abc-live-vpc"
      network_url  = "projects/gcp-abc/global/networks/abc-live-vpc"

      # PSC Endpoint IP (mgmt VPC용)
      psc_ips = {
        cloudsql = "10.250.21.20"
        redis    = "10.250.21.101"
      }

      # VM Static IP
      vm_ips = {
        web01 = "10.20.11.10"
        web02 = "10.20.11.20"
      }

      # Database/Cache 설정 경로
      database_path = "../../environments/LIVE/gcp-abc/60-database"
      cache_path    = "../../environments/LIVE/gcp-abc/65-cache"
    }
  }
}
```

### 2. bootstrap/10-network/terragrunt.hcl - Dependency 추가

**파일**: `bootstrap/10-network/terragrunt.hcl`

기존 gcby dependencies 아래에 abc dependencies 추가:

```hcl
# ============================================================================
# 프로젝트별 Database/Cache Dependencies
# ============================================================================

# gcby 프로젝트 dependencies (기존)
dependency "gcby_database" {
  config_path = local.common_vars.locals.projects.gcby.database_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-gcby-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "gcby_cache" {
  config_path = local.common_vars.locals.projects.gcby.cache_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-gcby-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ⚠️ abc 프로젝트 dependencies (신규)
dependency "abc_database" {
  config_path = local.common_vars.locals.projects.abc.database_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "abc_cache" {
  config_path = local.common_vars.locals.projects.abc.cache_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

### 3. bootstrap/10-network/terragrunt.hcl - PSC Endpoints 추가

같은 파일의 `locals` 섹션:

```hcl
locals {
  projects = local.common_vars.locals.projects

  # ... 기존 gcby PSC endpoints ...

  # ⚠️ abc PSC endpoints (신규)
  psc_endpoints_abc = {
    "abc-cloudsql" = {
      region                    = "us-west1"
      ip_address                = local.projects.abc.psc_ips.cloudsql
      target_service_attachment = dependency.abc_database.outputs.psc_service_attachment_link
      allow_global_access       = true
    }
    "abc-redis" = {
      region                    = "us-west1"
      ip_address                = local.projects.abc.psc_ips.redis
      target_service_attachment = dependency.abc_cache.outputs.psc_service_attachment_link
      allow_global_access       = true
    }
  }

  # 모든 프로젝트의 PSC endpoints 병합
  all_psc_endpoints = merge(
    local.psc_endpoints_gcby,
    local.psc_endpoints_abc,  # ⚠️ 추가
  )
}
```

### 4. 자동 반영 확인

위 3단계 완료 후 자동 생성되는 리소스:

- ✅ **VPC Peering**: `mgmt ↔ abc` (bootstrap/10-network/main.tf의 for_each)
- ✅ **DNS 레코드**: `abc-web01`, `abc-web02`, `abc-live-gdb-m1`, `abc-live-redis` (bootstrap/12-dns/layer.hcl)
- ✅ **PSC Endpoints**: mgmt VPC에서 abc Cloud SQL/Redis 접근 가능

---

## 레이어별 설정

### 00-project

**파일**: `environments/LIVE/gcp-abc/00-project/terraform.tfvars`

```hcl
# GCP 프로젝트 생성 설정
project_id   = "gcp-abc"
project_name = "abc"

# 활성화할 API
additional_apis = [
  "compute.googleapis.com",
  "servicenetworking.googleapis.com",
  "sqladmin.googleapis.com",
  "redis.googleapis.com",
]

# 프로젝트 라벨
labels = {
  environment = "live"
  team        = "product-team"
  cost-center = "engineering"
}
```

### 10-network

**파일**: `environments/LIVE/gcp-abc/10-network/terraform.tfvars`

```hcl
routing_mode = "GLOBAL"

# Subnet 설정은 common.naming.tfvars의 network_config에서 자동 생성
# 추가 수정 불필요

# Firewall Rules
firewall_rules = [
  {
    name           = "allow-ssh-from-iap"
    direction      = "INGRESS"
    ranges         = ["35.235.240.0/20"]
    allow_protocol = "tcp"
    allow_ports    = ["22"]
    target_tags    = ["ssh-from-iap"]
  },
  {
    name           = "allow-dmz-internal"
    direction      = "INGRESS"
    ranges         = ["10.20.10.0/24"]  # DMZ subnet
    allow_protocol = "all"
    target_tags    = ["dmz-zone"]
  },
  {
    name           = "allow-private-internal"
    direction      = "INGRESS"
    ranges         = ["10.20.11.0/24"]  # Private subnet
    allow_protocol = "all"
    target_tags    = ["private-zone"]
  },
]

# PSC 설정
enable_memorystore_psc_policy = true
enable_cloudsql_psc_policy = true
```

### 12-dns

**파일**: `environments/LIVE/gcp-abc/12-dns/terraform.tfvars`

```hcl
# Private DNS Zone 설정
zone_name   = "abc-delabsgames-internal"
dns_name    = "delabsgames.internal."
description = "Private DNS zone for abc VPC"
visibility  = "private"

# DNS 레코드는 terragrunt.hcl에서 network_config 기반 자동 생성
# 추가 레코드만 여기에 명시
dns_records = []

enable_dns_logging = false
```

### 60-database

**파일**: `environments/LIVE/gcp-abc/60-database/terraform.tfvars`

```hcl
# Cloud SQL 설정
database_version = "MYSQL_8_0"
tier            = "db-n1-standard-2"
disk_size       = 50
disk_type       = "PD_SSD"

# 가용성
availability_type = "REGIONAL"
enable_ha        = true

# 백업
backup_enabled               = true
backup_start_time           = "03:00"
backup_retention_count      = 7
point_in_time_recovery      = true

# Database/User는 main.tf의 locals에서 자동 생성
# 프로젝트명 기반: abc_gamedb, abc_app_user
databases = []
users = []

# PSC 설정
psc_enabled = true
```

### 50-workloads

**파일**: `environments/LIVE/gcp-abc/50-workloads/terraform.tfvars`

```hcl
# VM 인스턴스
instances = {
  "web-01" = {
    subnet_type     = "private"
    machine_type    = "e2-medium"
    boot_disk_size  = 50
    boot_disk_type  = "pd-standard"
    tags            = ["private-zone", "web-server"]
    metadata = {
      enable-oslogin = "TRUE"
    }
  }
  "web-02" = {
    subnet_type     = "private"
    machine_type    = "e2-medium"
    boot_disk_size  = 50
    boot_disk_type  = "pd-standard"
    tags            = ["private-zone", "web-server"]
  }
}

# subnet_type 자동 매핑
# dmz → common.naming.tfvars의 network_config.subnets.dmz
# private → network_config.subnets.private
```

---

## 배포 및 검증

### 1. Bootstrap 업데이트 (먼저 실행)

```bash
cd bootstrap

# Plan 확인
terragrunt run-all plan

# 예상 변경사항:
# - 10-network: VPC Peering "peering-mgmt-to-abc" 생성
# - 10-network: PSC Endpoints "abc-cloudsql", "abc-redis" 생성
# - 12-dns: DNS 레코드 "abc-web01", "abc-live-gdb-m1" 등 생성

# Apply
terragrunt run-all apply
```

### 2. 프로젝트 배포 (Phase 순서)

```bash
cd ../environments/LIVE/gcp-abc

# Phase 1: Project
cd 00-project && terragrunt apply
cd ..

# Phase 2: Network
cd 10-network && terragrunt apply
cd ..

# Phase 3: Database & Cache
cd 60-database && terragrunt apply
cd ../65-cache && terragrunt apply
cd ..

# Phase 4: DNS
cd 12-dns && terragrunt apply
cd ..

# Phase 5: Workloads
cd 50-workloads && terragrunt apply
cd ..
```

### 3. 연결 테스트

```bash
# 1. VPC Peering 확인
gcloud compute networks peerings list \
  --network=abc-live-vpc \
  --project=gcp-abc

# 예상 결과:
# NAME                   NETWORK         PEER_PROJECT      PEER_NETWORK
# peering-abc-to-mgmt    abc-live-vpc    delabs-gcp-mgmt   delabs-gcp-mgmt-vpc

# 2. PSC Forwarding Rule 확인 (mgmt VPC)
gcloud compute forwarding-rules list \
  --project=delabs-gcp-mgmt \
  --filter="name:abc"

# 예상 결과:
# NAME                REGION      IP_ADDRESS      TARGET
# abc-cloudsql-psc-fr us-west1    10.250.21.20    <service-attachment>
# abc-redis-psc-fr    us-west1    10.250.21.101   <service-attachment>

# 3. DNS 레코드 확인
gcloud dns record-sets list \
  --zone=delabsgames-internal \
  --project=delabs-gcp-mgmt \
  --filter="name:abc"

# 4. Cloud SQL 연결 테스트 (mgmt bastion에서)
gcloud compute ssh bastion --project=delabs-gcp-mgmt --zone=asia-northeast3-a
mysql -h abc-live-gdb-m1.delabsgames.internal -u root -p
```

---

## 트러블슈팅

### 문제 1: VPC Peering 실패

**증상**:
```
Error: Error waiting for Creating Network Peering: Peering already exists
```

**해결**:
```bash
# 기존 Peering 확인 및 삭제
gcloud compute networks peerings delete peering-abc-to-mgmt \
  --network=abc-live-vpc \
  --project=gcp-abc
```

### 문제 2: PSC Service Attachment 없음

**증상**:
```
Error: Dependency abc_database has no outputs
```

**원인**: Database가 아직 생성되지 않음

**해결**:
1. abc 프로젝트의 60-database 먼저 apply
2. Bootstrap 10-network 다시 apply

### 문제 3: DNS 레코드 IP 불일치

**증상**: DNS 레코드가 잘못된 IP를 가리킴

**해결**:
1. `bootstrap/common.hcl`의 projects.abc.psc_ips 확인
2. `environments/LIVE/gcp-abc/common.naming.tfvars`의 network_config.psc_endpoints 확인
3. 두 값이 일치하는지 확인 (mgmt용 vs abc용)

---

## 체크리스트

### 프로젝트 폴더

- [ ] proj-default-templet 복사 완료
- [ ] root.hcl의 project_state_prefix 변경
- [ ] common.naming.tfvars의 project_id, project_name 변경
- [ ] common.naming.tfvars의 network_config 설정
- [ ] 모든 terraform.tfvars 검토 완료

### Bootstrap 통합

- [ ] bootstrap/common.hcl에 projects.abc 추가
- [ ] bootstrap/10-network/terragrunt.hcl에 abc dependencies 추가 (2개)
- [ ] bootstrap/10-network/terragrunt.hcl에 psc_endpoints_abc 추가
- [ ] bootstrap/10-network/terragrunt.hcl의 merge 구문에 abc 추가

### 배포 검증

- [ ] Bootstrap apply 성공 (VPC Peering, PSC, DNS)
- [ ] 00-project apply 성공 (프로젝트 생성)
- [ ] 10-network apply 성공 (VPC, Subnet)
- [ ] 60-database apply 성공 (Cloud SQL)
- [ ] 65-cache apply 성공 (Redis)
- [ ] 12-dns apply 성공 (Private DNS Zone)
- [ ] 50-workloads apply 성공 (VM)

### 연결 테스트

- [ ] VPC Peering 상태 ACTIVE 확인
- [ ] PSC Forwarding Rule 생성 확인
- [ ] DNS 레코드 등록 확인
- [ ] mgmt bastion에서 abc Cloud SQL 연결 확인
- [ ] mgmt bastion에서 abc Redis 연결 확인
- [ ] abc VM에서 Cloud SQL/Redis 연결 확인

---

## 요약: 새 프로젝트 추가 단계

| 단계 | 위치 | 작업 | 예상 시간 |
|-----|------|------|---------|
| 1 | Local | 템플릿 복사 및 설정 파일 수정 | 10분 |
| 2 | bootstrap/common.hcl | projects 맵에 신규 프로젝트 추가 | 5분 |
| 3 | bootstrap/10-network/terragrunt.hcl | dependencies 및 PSC endpoints 추가 | 10분 |
| 4 | bootstrap/ | Bootstrap apply (VPC Peering, PSC, DNS) | 5분 |
| 5 | environments/LIVE/gcp-abc/ | 프로젝트 레이어 순차 배포 | 30분 |
| 6 | 검증 | 연결 테스트 및 검증 | 10분 |
| **합계** | | | **70분** |

---

## 참고 자료

- [Bootstrap README](../../bootstrap/README.md) - Bootstrap 구조 상세
- [Terragrunt 사용법](./terragrunt-usage.md) - Terragrunt 명령어
- [네트워크 설계](../architecture/network-design.md) - PSC 아키텍처
- [트러블슈팅](../troubleshooting/common-errors.md) - 일반 오류 해결

---

**Last Updated: 2025-12-03**
**Version: Bootstrap 일반화 v1.0**
