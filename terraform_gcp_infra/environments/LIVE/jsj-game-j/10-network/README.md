# 10-network 레이어
> Terragrunt: environments/LIVE/proj-default-templet/10-network/terragrunt.hcl


VPC 네트워크, 서브넷, 방화벽, Cloud NAT, Private Service Connect(PSC)를 구성합니다. Cloud SQL과 같은 서비스가 Private IP로 동작하려면 이 레이어의 설정이 필수입니다.

## 주요 기능
- `modules/network-dedicated-vpc` 기반 VPC 및 서브넷 생성
- **용도별 서브넷 지원**: Web, App, DB 서브넷을 분리하여 보안 강화
- Cloud Router + NAT 구성으로 외부 인터넷 접근 지원
- 입력값 기반 방화벽 규칙 생성 (INGRESS/EGRESS)
- Cloud SQL Private IP 연결을 위한 Service Networking(Private Service Connect) 예약

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 주요 항목 설명:
   - `subnet_primary_cidr`, `subnet_backup_cidr`: 조직 표준에 맞는 CIDR
   - **`subnet_web_cidr`**: Web 서버용 서브넷 (예: 10.10.0.0/24)
   - **`subnet_app_cidr`**: App 서버용 서브넷 (예: 10.10.1.0/24)
   - **`subnet_db_cidr`**: DB 프록시용 서브넷 (예: 10.10.2.0/24)
   - `pods_cidr`, `services_cidr`: GKE 등에서 사용할 보조 CIDR
   - `firewall_rules`: IAP, 헬스 체크, 내부 통신 등 필요한 규칙 정의
   - `enable_private_service_connection`: Cloud SQL Private IP를 사용할 경우 `true`
   - `private_service_connection_prefix_length`: PSC용 예약 CIDR 크기 (기본 /24)
   - `private_service_connection_name`: 비워두면 naming 규칙으로 자동 생성

> ⚠️ PSC를 비활성화하려면 `enable_private_service_connection = false`로 설정하세요.

## Terragrunt 실행 절차
```bash
cd environments/prod/proj-default-templet/10-network
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 서브넷 구성 예시

이 레이어는 총 **5개의 서브넷**을 생성합니다:

1. **Primary 서브넷** (`subnet_primary_cidr`): GKE 등 기본 용도
2. **Backup 서브넷** (`subnet_backup_cidr`): DR/백업 용도
3. **Web 서브넷** (`subnet_web_cidr`): 웹 서버 전용
4. **App 서브넷** (`subnet_app_cidr`): 애플리케이션 서버 전용
5. **DB 서브넷** (`subnet_db_cidr`): DB 프록시 전용

### 50-workloads에서 사용하는 방법

```hcl
# 50-workloads/terraform.tfvars
instances = {
  "web-01" = {
    subnetwork_self_link = "projects/your-project/regions/us-central1/subnetworks/{project-name}-prod-subnet-web"
    ...
  }
  "app-01" = {
    subnetwork_self_link = "projects/your-project/regions/us-central1/subnetworks/{project-name}-prod-subnet-app"
    ...
  }
}
```

## 참고
- Service Networking 연결은 Cloud SQL 레이어(60-database)에서 자동으로 사용됩니다.
- VPC/서브넷 Self Link는 naming 모듈이 자동 제공하므로 다른 레이어에서 별도 입력이 필요 없습니다.
- 용도별 서브넷은 **보안 강화**를 위해 각 계층을 물리적으로 분리합니다.
