# 신규 프로젝트 추가 가이드 (고급)

이 문서는 Bootstrap 통합이 필요한 경우의 상세 가이드입니다.

> **기본 프로젝트 생성**은 [CREATE_NEW_PROJECT.md](../CREATE_NEW_PROJECT.md)를 참고하세요.

## 목차

1. [개요](#개요)
2. [Bootstrap 통합이 필요한 경우](#bootstrap-통합이-필요한-경우)
3. [Bootstrap 설정 추가](#bootstrap-설정-추가)
4. [배포 순서](#배포-순서)
5. [검증](#검증)

---

## 개요

`proj-default-templet`으로 생성된 프로젝트는 독립적으로 동작할 수 있습니다.

하지만 다음 기능이 필요한 경우 Bootstrap 설정을 추가해야 합니다:

- Management VPC와 VPC Peering
- 중앙 집중식 PSC (Private Service Connect) Endpoint
- 중앙 집중식 Private DNS

---

## Bootstrap 통합이 필요한 경우

| 요구사항 | Bootstrap 필요 여부 |
|---------|-------------------|
| 독립적인 프로젝트 운영 | 불필요 |
| Management VPC에서 DB/Redis 접근 | **필요** |
| Bastion에서 새 프로젝트 리소스 접근 | **필요** |
| 중앙 DNS에 레코드 추가 | **필요** |

---

## Bootstrap 설정 추가

### 1. bootstrap/common.hcl - projects 맵 추가

```hcl
# bootstrap/common.hcl

locals {
  projects = {
    # 기존 프로젝트들...
    gcby = { ... }

    # 신규 프로젝트 추가
    newgame = {
      project_id   = "gcp-newgame"
      environment  = "live"
      vpc_name     = "newgame-live-vpc"
      network_url  = "projects/gcp-newgame/global/networks/newgame-live-vpc"

      # mgmt VPC에 생성할 PSC Endpoint IP
      psc_ips = {
        cloudsql = "10.250.30.20"   # mgmt VPC 대역
        redis    = "10.250.30.101"
      }

      # Database/Cache 경로 (dependency용)
      database_path = "../../environments/LIVE/gcp-newgame/60-database"
      cache_path    = "../../environments/LIVE/gcp-newgame/65-cache"
    }
  }
}
```

### 2. bootstrap/10-network/terragrunt.hcl - Dependency 추가

```hcl
# 신규 프로젝트 dependency
dependency "newgame_database" {
  config_path = local.common_vars.locals.projects.newgame.database_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-newgame-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "newgame_cache" {
  config_path = local.common_vars.locals.projects.newgame.cache_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-newgame-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

### 3. bootstrap/10-network/terragrunt.hcl - PSC Endpoints 추가

```hcl
inputs = merge(
  local.common_vars.locals,
  local.layer_vars.locals,
  {
    psc_endpoints = merge(
      # 기존 프로젝트 PSC...

      # 신규 프로젝트 PSC
      {
        "newgame-cloudsql" = {
          region                    = "us-west1"
          ip_address                = local.projects.newgame.psc_ips.cloudsql
          target_service_attachment = dependency.newgame_database.outputs.psc_service_attachment_link
          allow_global_access       = true
        }
        "newgame-redis" = {
          region                    = "us-west1"
          ip_address                = local.projects.newgame.psc_ips.redis
          target_service_attachment = dependency.newgame_cache.outputs.psc_service_attachment_link
          allow_global_access       = true
        }
      }
    )
  }
)
```

---

## 배포 순서

Bootstrap 통합 시 배포 순서가 중요합니다.

### Phase 1: 프로젝트 기본 인프라

```bash
cd environments/LIVE/gcp-newgame

# 1. 프로젝트 생성
cd 00-project && terragrunt apply && cd ..

# 2. 네트워크
cd 10-network && terragrunt apply && cd ..

# 3. Database & Cache (PSC Service Attachment 생성됨)
cd 60-database && terragrunt apply && cd ..
cd 65-cache && terragrunt apply && cd ..
```

### Phase 2: Bootstrap 업데이트

```bash
cd bootstrap

# VPC Peering, PSC Endpoint 생성 (Terragrunt 0.93+ 구문)
terragrunt run --all -- apply
```

### Phase 3: 프로젝트 나머지 레이어

```bash
cd environments/LIVE/gcp-newgame

# DNS, Workloads, PSC, LB
cd 12-dns && terragrunt apply && cd ..
cd 50-workloads && terragrunt apply && cd ..
cd 66-psc-endpoints && terragrunt apply && cd ..
cd 70-loadbalancers/gs && terragrunt apply && cd ..
```

---

## 검증

### VPC Peering 확인

```bash
gcloud compute networks peerings list \
  --network=newgame-live-vpc \
  --project=gcp-newgame
```

### PSC Endpoint 확인 (mgmt VPC)

```bash
gcloud compute forwarding-rules list \
  --project=delabs-gcp-mgmt \
  --filter="name:newgame"
```

### 연결 테스트 (Bastion에서)

```bash
# Cloud SQL
mysql -h newgame-live-gdb-m1.delabsgames.internal -u root -p

# Redis
redis-cli -h newgame-live-redis.delabsgames.internal -p 6379
```

> **참고**: Redis Cluster는 자체적으로 PSC를 자동 생성합니다 (`sca-auto-addr-*`). `66-psc-endpoints`에서는 cross-project 등록만 수행합니다.

---

## Terragrunt 제약사항

### locals에서 dependency 참조 불가

```hcl
# 잘못된 예시
locals {
  psc = dependency.newgame_database.outputs...  # 에러!
}

# 올바른 예시
inputs = {
  psc = dependency.newgame_database.outputs...  # OK
}
```

### 평가 순서

```
1. dependency 블록
   ↓
2. locals 블록 (local 변수만 참조 가능)
   ↓
3. inputs 블록 (local + dependency 모두 가능)
```

---

## 관련 문서

- [CREATE_NEW_PROJECT.md](../CREATE_NEW_PROJECT.md) - 기본 프로젝트 생성
- [Bootstrap README](../../bootstrap/README.md) - Bootstrap 구조
- [네트워크 설계](../architecture/network-design.md) - PSC 아키텍처

---

**Last Updated**: 2025-12-08
