# 전용 VPC 네트워크 모듈

이 모듈은 전용 네트워크 토폴로지를 위한 서브넷, Cloud NAT 및 방화벽 규칙이 포함된 Google Cloud VPC 네트워크를 생성하고 관리합니다.

## 기능

- **VPC 네트워크**: 구성 가능한 라우팅 모드 (GLOBAL 또는 REGIONAL)를 가진 사용자 정의 VPC
- **서브넷**: 보조 IP 범위를 가진 여러 지역의 다중 서브넷
- **비공개 Google 액세스**: Google API에 대한 비공개 액세스 활성화
- **Cloud NAT**: 프라이빗 인스턴스가 인터넷에 액세스하기 위한 관리형 NAT 게이트웨이
- **Cloud Router**: Cloud NAT 및 BGP 라우팅에 필요
- **방화벽 규칙**: 프로토콜 및 포트 제어가 가능한 유연한 방화벽 구성

## 사용법

### 단일 서브넷이 있는 기본 VPC

```hcl
module "vpc" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "my-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region = "us-central1"
      cidr   = "10.0.0.0/24"
    }
  }

  nat_region = "us-central1"
}
```

### 여러 서브넷과 보조 범위가 있는 VPC

```hcl
module "vpc_multi_region" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "prod-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region                = "us-central1"
      cidr                  = "10.0.0.0/24"
      private_google_access = true
      secondary_ranges = [
        {
          name = "pods"
          cidr = "10.1.0.0/16"
        },
        {
          name = "services"
          cidr = "10.2.0.0/16"
        }
      ]
    }
    subnet-us-east = {
      region                = "us-east1"
      cidr                  = "10.0.1.0/24"
      private_google_access = true
    }
  }

  nat_region           = "us-central1"
  nat_min_ports_per_vm = 2048
}
```

### 방화벽 규칙이 있는 VPC

```hcl
module "vpc_with_firewall" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "my-project-id"
  vpc_name     = "secure-vpc"
  routing_mode = "GLOBAL"

  subnets = {
    subnet-us-central = {
      region = "us-central1"
      cidr   = "10.0.0.0/24"
    }
  }

  nat_region = "us-central1"

  firewall_rules = [
    {
      name           = "allow-ssh-from-iap"
      direction      = "INGRESS"
      ranges         = ["35.235.240.0/20"]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      priority       = 1000
      description    = "Identity-Aware Proxy에서 SSH 허용"
    },
    {
      name           = "allow-internal"
      direction      = "INGRESS"
      ranges         = ["10.0.0.0/8"]
      allow_protocol = "all"
      priority       = 65534
      description    = "내부 트래픽 허용"
    },
    {
      name           = "allow-http-from-lb"
      direction      = "INGRESS"
      ranges         = ["130.211.0.0/22", "35.191.0.0/16"]
      allow_protocol = "tcp"
      allow_ports    = ["80", "443"]
      target_tags    = ["http-server"]
      priority       = 1000
      description    = "로드 밸런서에서 HTTP/HTTPS 허용"
    }
  ]
}
```

### 완전한 프로덕션 예제

```hcl
module "prod_network" {
  source = "../../modules/network-dedicated-vpc"

  project_id   = "prod-project-123"
  vpc_name     = "prod-vpc"
  routing_mode = "GLOBAL"

  # 고가용성을 위한 다중 지역 서브넷
  subnets = {
    app-us-central = {
      region                = "us-central1"
      cidr                  = "10.10.0.0/24"
      private_google_access = true
      secondary_ranges = [
        {
          name = "gke-pods"
          cidr = "10.20.0.0/16"
        },
        {
          name = "gke-services"
          cidr = "10.30.0.0/16"
        }
      ]
    }
    app-us-east = {
      region                = "us-east1"
      cidr                  = "10.11.0.0/24"
      private_google_access = true
    }
    db-us-central = {
      region                = "us-central1"
      cidr                  = "10.12.0.0/24"
      private_google_access = true
    }
  }

  # 아웃바운드 인터넷 액세스를 위한 Cloud NAT
  nat_region           = "us-central1"
  nat_min_ports_per_vm = 2048

  # 포괄적인 방화벽 규칙
  firewall_rules = [
    {
      name           = "allow-ssh-iap"
      ranges         = ["35.235.240.0/20"]
      allow_protocol = "tcp"
      allow_ports    = ["22"]
      description    = "IAP를 통한 SSH"
    },
    {
      name           = "allow-health-checks"
      ranges         = ["35.191.0.0/16", "130.211.0.0/22"]
      allow_protocol = "tcp"
      allow_ports    = ["80", "443"]
      target_tags    = ["http-server"]
      description    = "GCP 로드 밸런서의 상태 확인"
    },
    {
      name           = "allow-internal-all"
      ranges         = ["10.0.0.0/8"]
      allow_protocol = "all"
      priority       = 65534
      description    = "내부 VPC 통신"
    }
  ]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|------|
| project_id | GCP 프로젝트 ID | string | - | yes |
| vpc_name | VPC 네트워크 이름 | string | - | yes |
| routing_mode | 라우팅 모드 (GLOBAL 또는 REGIONAL) | string | "GLOBAL" | no |
| subnets | 생성할 서브넷 맵 | map(object) | - | yes |
| nat_region | Cloud NAT를 생성할 지역 | string | - | yes |
| nat_min_ports_per_vm | NAT의 VM당 최소 포트 수 | number | 1024 | no |
| firewall_rules | 방화벽 규칙 목록 | list(object) | [] | no |

### 서브넷 객체 구조

```hcl
{
  region                = string        # 필수: GCP 지역
  cidr                  = string        # 필수: IP CIDR 범위
  private_google_access = bool          # 선택: 비공개 Google 액세스 활성화 (기본값: true)
  secondary_ranges = list(object({      # 선택: GKE용 보조 IP 범위
    name = string
    cidr = string
  }))
}
```

### 방화벽 규칙 객체 구조

```hcl
{
  name           = string              # 필수: 규칙 이름
  direction      = string              # 선택: INGRESS 또는 EGRESS (기본값: INGRESS)
  ranges         = list(string)        # 선택: 소스/대상 IP 범위 (INGRESS는 source, EGRESS는 destination)
  allow_protocol = string              # 선택: tcp, udp, icmp 또는 all (기본값: tcp)
  allow_ports    = list(string)        # 선택: 포트 목록 (기본값: [])
  priority       = number              # 선택: 우선순위 (기본값: 1000)
  target_tags    = list(string)        # 선택: 대상 네트워크 태그
  disabled       = bool                # 선택: 규칙 비활성화 (기본값: false)
  description    = string              # 선택: 규칙 설명
}
```

> **참고**: `direction = "EGRESS"`인 경우 `ranges`는 `destination_ranges`로 적용되며, INGRESS일 때는 `source_ranges`로 적용됩니다.
> **기본값**: EGRESS에서 `ranges`를 생략하면 자동으로 `["0.0.0.0/0"]`이 적용되어 모든 아웃바운드 트래픽이 허용됩니다.

## 출력 값

| 이름 | 설명 |
|------|------|
| vpc_self_link | VPC 네트워크의 셀프 링크 |
| subnet_ids | 서브넷 이름에서 셀프 링크로의 맵 |

## 모범 사례

1. **IP 계획**: CIDR 범위를 신중하게 계획하여 충돌 방지
2. **비공개 Google 액세스**: 외부 IP 없이 Google API에 액세스해야 하는 서브넷에 활성화
3. **보조 범위**: GKE 파드 및 서비스 IP 범위에 사용
4. **NAT 게이트웨이**: 고가용성을 위해 여러 지역에 배포
5. **방화벽 규칙**: 최소 권한 원칙 준수 - 필요한 트래픽만 허용
6. **네트워크 태그**: 방화벽 규칙 타겟팅을 위한 일관된 태그 전략 사용
7. **우선순위**: 규칙 구성을 위한 우선순위 범위 사용 (예: 100-999는 중요, 1000+ 일반)

## 일반적인 방화벽 규칙 예제

### IAP에서 SSH 허용
```hcl
{
  name           = "allow-ssh-iap"
  ranges         = ["35.235.240.0/20"]
  allow_protocol = "tcp"
  allow_ports    = ["22"]
}
```

### 내부 트래픽 허용
```hcl
{
  name           = "allow-internal"
  ranges         = ["10.0.0.0/8"]
  allow_protocol = "all"
  priority       = 65534
}
```

### 로드 밸런서 상태 확인 허용
```hcl
{
  name           = "allow-health-checks"
  ranges         = ["35.191.0.0/16", "130.211.0.0/22"]
  allow_protocol = "tcp"
  allow_ports    = ["80", "443"]
  target_tags    = ["http-server"]
}
```

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30

## 필요한 권한

- `roles/compute.networkAdmin` - VPC 및 서브넷 생성
- `roles/compute.securityAdmin` - 방화벽 규칙 생성

## 참고사항

- Cloud NAT는 지정된 `nat_region`에만 생성됩니다
- 다중 지역 배포의 경우 지역별로 별도의 NAT 게이트웨이를 생성하세요
- 비공개 Google 액세스를 사용하면 외부 IP가 없는 인스턴스가 Google API에 액세스할 수 있습니다
- 보조 IP 범위는 주로 GKE 클러스터 (파드 및 서비스)에 사용됩니다
