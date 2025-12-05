# Network Configuration
# region은 terragrunt.hcl에서 region_primary 자동 주입
routing_mode = "GLOBAL"

# Additional dedicated subnets (DMZ/Private zones)
# 이제 common.naming.tfvars의 network_config.subnets에서 중앙 관리됩니다.
# terragrunt.hcl에서 동적으로 생성하므로 여기서는 정의하지 않습니다.
# additional_subnets = []  # terragrunt.hcl에서 자동 생성

# Subnet 이름과 CIDR은 terragrunt.hcl에서 자동 생성
# 형식: {project_name}-subnet-{type} (dmz, private, psc)

# Private Service Connection (VPC Peering 방식) - PSC 쓰므로 불필요
enable_private_service_connection = false

# Cloud NAT configuration
nat_min_ports_per_vm = 1024

# Firewall rules
# terragrunt.hcl에서 common.naming.tfvars의 network_config를 사용해 동적 생성됩니다.
# (mgmt_subnet_cidr, dmz, private CIDR 자동 참조)
firewall_rules = []

# Memorystore Enterprise용 PSC 자동 구성
enable_memorystore_psc_policy = true
# memorystore_psc_region은 terragrunt.hcl에서 region_primary 자동 주입
# memorystore_psc_subnet_name은 terragrunt.hcl에서 자동 생성 (기본: private subnet)
memorystore_psc_connection_limit = 8

# Cloud SQL용 PSC Endpoint 구성 (Private subnet 전용 접근)
# Service class: google-cloud-sql
enable_cloudsql_psc_policy = true
# cloudsql_psc_region은 terragrunt.hcl에서 region_primary 자동 주입
# cloudsql_psc_subnet_name은 terragrunt.hcl에서 자동 생성 (기본: private subnet)
cloudsql_psc_connection_limit = 5  # Master + Read Replicas
