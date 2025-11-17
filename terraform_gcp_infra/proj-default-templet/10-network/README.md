# 10-network 레이어
> Terragrunt: environments/LIVE/jsj-game-l/10-network/terragrunt.hcl


VPC 네트워크, 서브넷, 방화벽, Cloud NAT, Private Service Connect(PSC)를 구성합니다. Cloud SQL과 같은 서비스가 Private IP로 동작하려면 이 레이어의 설정이 필수입니다.

## 주요 기능
- `modules/network-dedicated-vpc` 기반 VPC 및 서브넷 생성
- **역할별 서브넷 지원**: DMZ(외부 노출), Private/WAS, DB 서브넷을 `additional_subnets` 리스트로 선언
- Cloud Router + NAT (DMZ 서브넷 대상) 구성으로 외부 인터넷 접근을 통제
- 입력값 기반 방화벽 규칙 생성 (INGRESS/EGRESS)
- Cloud SQL Private IP 연결을 위한 Service Networking(Private Service Connect) 예약

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 주요 항목 설명:
   - `additional_subnets`: DMZ/Private/DB 등 역할별 서브넷 리스트 (name/region/cidr)
- `dmz_subnet_name`, `private_subnet_name`, `db_subnet_name`: `additional_subnets`에서 사용할 서브넷 이름
- `firewall_rules`: IAP, 헬스 체크, 내부 통신 등 필요한 규칙 정의
- `enable_private_service_connection`: Cloud SQL Private IP를 사용할 경우 `true`
- `private_service_connection_prefix_length`: PSC용 예약 CIDR 크기 (기본 /24)
- `private_service_connection_name`: 비워두면 naming 규칙으로 자동 생성
- `enable_memorystore_psc_policy`, `memorystore_psc_*`: Memorystore Enterprise(PSC)용 Service Connection Policy 자동 생성 설정

> ⚠️ PSC를 비활성화하려면 `enable_private_service_connection = false`로 설정하세요.
> ⚠️ Memorystore Enterprise를 사용할 경우 `enable_memorystore_psc_policy = true`로 설정하고, PSC가 사용할 서브넷/리전을 정확히 지정해야 합니다.

## Terragrunt 실행 절차
```bash
cd environments/prod/proj-default-templet/10-network
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 서브넷 구성 예시

이 레이어는 `additional_subnets`에 선언한 서브넷만 생성하며, Primary/Backup 서브넷은 더 이상 사용하지 않습니다:

```hcl
additional_subnets = [
  { name = "game-l-subnet-dmz",     region = "asia-northeast3", cidr = "10.3.0.0/24" },
  { name = "game-l-subnet-private", region = "asia-northeast3", cidr = "10.3.1.0/24" },
  { name = "game-l-subnet-db",      region = "asia-northeast3", cidr = "10.3.2.0/24" }
]

dmz_subnet_name     = "game-l-subnet-dmz"
private_subnet_name = "game-l-subnet-private"
db_subnet_name      = "game-l-subnet-db"
```

### 50-workloads에서 사용하는 방법

```hcl
# 50-workloads/terraform.tfvars
instances = {
  "web-01" = {
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-dmz"
    ...
  }
  "app-01" = {
    subnetwork_self_link = "projects/jsj-game-l/regions/asia-northeast3/subnetworks/game-l-subnet-private"
    ...
  }
}
```

## 참고
- Service Networking 연결은 Cloud SQL 레이어(60-database)에서 자동으로 사용됩니다.
- 서브넷 self-link는 `additional_subnets`에서 선언한 값을 그대로 사용해야 하므로 50-workloads/70-loadbalancer 등에서도 명시적으로 입력해야 합니다.
- NAT는 기본적으로 DMZ/Private/DB 서브넷 전체에 적용되며, 필요 시 `nat_subnet_self_links` 계산 로직을 조정해 특정 서브넷만 인터넷 egress를 허용할 수 있습니다.
- 용도별 서브넷은 **보안 강화**를 위해 각 계층을 물리적으로 분리합니다.
