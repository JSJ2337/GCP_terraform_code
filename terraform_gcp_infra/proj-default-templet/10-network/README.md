# 10-network 레이어
> Terragrunt: environments/LIVE/{project}/10-network/terragrunt.hcl


VPC 네트워크, 서브넷, 방화벽, Cloud NAT, Private Service Connect(PSC)를 구성합니다. Cloud SQL과 같은 서비스가 Private IP로 동작하려면 이 레이어의 설정이 필수입니다.

## 주요 기능
- `modules/network-dedicated-vpc` 기반 VPC 및 서브넷 생성
- **역할별 서브넷 지원**: DMZ(외부 노출), Private/WAS, DB 서브넷을 `additional_subnets` 리스트로 선언
- **동적 서브넷 이름 생성**: terragrunt.hcl에서 `project_name`과 `region_primary` 기반으로 자동 생성
- Cloud Router + NAT (DMZ 서브넷 대상) 구성으로 외부 인터넷 접근을 통제
- 입력값 기반 방화벽 규칙 생성 (INGRESS/EGRESS)
- Cloud SQL Private IP 연결을 위한 Service Networking(Private Service Connect) 예약

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 주요 항목 설명:
   - `additional_subnets`: DMZ/Private/DB 등 역할별 서브넷 리스트 (**CIDR만 정의**)
     - `name`과 `region`은 terragrunt.hcl에서 자동 생성됨
   - `firewall_rules`: IAP, 헬스 체크, 내부 통신 등 필요한 규칙 정의
   - `enable_private_service_connection`: Cloud SQL Private IP를 사용할 경우 `true`
   - `private_service_connection_prefix_length`: PSC용 예약 CIDR 크기 (기본 /24)
   - `private_service_connection_name`: 비워두면 naming 규칙으로 자동 생성
   - `enable_memorystore_psc_policy`: Memorystore Enterprise(PSC)용 Service Connection Policy 자동 생성 설정
     - `memorystore_psc_region`과 `memorystore_psc_subnet_name`은 terragrunt.hcl에서 자동 생성됨

> ⚠️ PSC를 비활성화하려면 `enable_private_service_connection = false`로 설정하세요.
> ⚠️ Memorystore Enterprise를 사용할 경우 `enable_memorystore_psc_policy = true`로 설정하세요.

## 동적 생성 구조
terragrunt.hcl에서 `common.naming.tfvars`의 `project_name`과 `region_primary`를 기반으로 자동 생성:
- 서브넷 이름: `{project_name}-subnet-{type}` (예: `game-n-subnet-dmz`, `game-n-subnet-private`, `game-n-subnet-db`)
- 서브넷 리전: `region_primary` 값 사용
- PSC 설정: `region_primary`와 `private_subnet_name` 자동 매핑

## Terragrunt 실행 절차
```bash
cd environments/prod/proj-default-templet/10-network
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 서브넷 구성 예시

### terraform.tfvars (사용자 입력)
CIDR 블록만 정의하면 됩니다:

```hcl
# Network Configuration
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/WAS/DB zones)
# name, region은 terragrunt.hcl에서 project_name, region_primary 기반 자동 생성
additional_subnets = [
  {
    cidr = "10.3.0.0/24"  # DMZ subnet
  },
  {
    cidr = "10.3.1.0/24"  # Private subnet
  },
  {
    cidr = "10.3.2.0/24"  # DB subnet
  }
]

# Memorystore Enterprise용 PSC 자동 구성
enable_memorystore_psc_policy = true
# memorystore_psc_region과 memorystore_psc_subnet_name은 terragrunt.hcl에서 자동 생성
memorystore_psc_connection_limit = 8
```

### terragrunt.hcl (자동 생성)
서브넷 이름과 리전을 자동 생성:

```hcl
locals {
  project_name   = local.common_inputs.project_name      # 예: "game-n"
  region_primary = local.common_inputs.region_primary    # 예: "asia-northeast3"

  # 자동 생성된 서브넷 이름들
  dmz_subnet_name     = "${local.project_name}-subnet-dmz"      # "game-n-subnet-dmz"
  private_subnet_name = "${local.project_name}-subnet-private"  # "game-n-subnet-private"
  db_subnet_name      = "${local.project_name}-subnet-db"       # "game-n-subnet-db"

  # additional_subnets에 name과 region 자동 추가
  additional_subnets_with_metadata = [
    for idx, subnet in try(local.layer_inputs.additional_subnets, []) :
    merge(subnet, {
      name   = "${local.project_name}-subnet-${local.subnet_types[idx]}"
      region = local.region_primary
    })
  ]
}
```

### 50-workloads에서 사용하는 방법
여전히 하드코딩이 필요하지만, 이제 패턴이 일관적입니다:

```hcl
# 50-workloads/terraform.tfvars
# project_name이 "game-n", region이 "asia-northeast3"인 경우:
instances = {
  "web-01" = {
    subnetwork_self_link = "projects/jsj-game-n/regions/asia-northeast3/subnetworks/game-n-subnet-dmz"
    ...
  }
  "app-01" = {
    subnetwork_self_link = "projects/jsj-game-n/regions/asia-northeast3/subnetworks/game-n-subnet-private"
    ...
  }
}
```

> 💡 50-workloads 레이어도 향후 동적 생성으로 전환 예정입니다.

## 참고
- Service Networking 연결은 Cloud SQL 레이어(60-database)에서 자동으로 사용됩니다.
- 서브넷 self-link는 `additional_subnets`에서 선언한 값을 그대로 사용해야 하므로 50-workloads/70-loadbalancer 등에서도 명시적으로 입력해야 합니다.
- NAT는 기본적으로 DMZ/Private/DB 서브넷 전체에 적용되며, 필요 시 `nat_subnet_self_links` 계산 로직을 조정해 특정 서브넷만 인터넷 egress를 허용할 수 있습니다.
- 용도별 서브넷은 **보안 강화**를 위해 각 계층을 물리적으로 분리합니다.
