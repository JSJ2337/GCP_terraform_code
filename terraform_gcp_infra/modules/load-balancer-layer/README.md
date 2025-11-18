# Load Balancer Layer 모듈

이 모듈은 **naming** 모듈과 **load-balancer** 모듈을 조합하여 프로젝트 표준에 맞는 Load Balancer를 생성하는 High-Level Wrapper 모듈입니다.

## 개요

`load-balancer-layer`는 다음을 자동화합니다:
- **Naming Convention**: naming 모듈을 사용하여 일관된 리소스 이름 생성
- **Auto Instance Groups**: workloads 레이어의 Instance Group을 자동으로 Backend에 추가
- **Load Balancer 생성**: load-balancer 모듈을 호출하여 실제 LB 리소스 생성

## 모듈 구조

```
load-balancer-layer (High-level wrapper)
  ↓ 호출
  ├─ naming 모듈 → 리소스 이름 생성
  └─ load-balancer 모듈 → 실제 GCP LB 리소스 생성
```

## 사용 대상

- **환경 레이어**: `environments/LIVE/*/70-loadbalancers/lobby`, `web` 등
- **Terragrunt와 함께 사용**: Instance Group 자동 필터링 기능 제공

## 주요 기능

### 1. 자동 네이밍

naming 모듈을 통해 다음을 자동 생성:
- Backend Service 이름
- Forwarding Rule 이름
- Health Check 이름
- Static IP 이름
- URL Map 이름
- Target Proxy 이름

### 2. Auto Instance Groups

`auto_instance_groups` 변수로 전달된 Instance Group을 자동으로 Backend에 추가합니다.

```hcl
auto_instance_groups = {
  "web-ig-1" = "projects/.../instanceGroups/web-ig-1"
  "web-ig-2" = "projects/.../instanceGroups/web-ig-2"
}
```

이들은 다음 설정으로 Backend에 추가됩니다:
- `balancing_mode`: `auto_backend_balancing_mode` 변수값 (기본: UTILIZATION)
- `capacity_scaler`: `auto_backend_capacity_scaler` 변수값 (기본: 1.0)
- `max_utilization`: `auto_backend_max_utilization` 변수값 (기본: 0.8)

### 3. 수동 Backend 추가 지원

`auto_instance_groups` 외에도 `backends` 변수로 수동 Backend 추가 가능:

```hcl
backends = [
  {
    group           = "projects/.../instanceGroups/manual-ig"
    balancing_mode  = "RATE"
    max_rate        = 1000
  }
]
```

## 사용법

### Terragrunt와 함께 사용 (권장)

**lobby/terragrunt.hcl**:
```hcl
terraform {
  source = "../../../../../modules/load-balancer-layer"
}

dependency "workloads" {
  config_path = "../../50-workloads"
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  {
    # "lobby"가 포함된 Instance Group만 자동으로 Backend에 추가
    auto_instance_groups = {
      for name, link in dependency.workloads.outputs.instance_groups :
      name => link
      if length(regexall("lobby", lower(name))) > 0
    }
  }
)
```

**lobby/terraform.tfvars**:
```hcl
lb_type           = "http"
region            = "asia-northeast3"
use_ssl           = true
ssl_certificates  = ["projects/my-project/global/sslCertificates/my-cert"]

# Health Check 설정
health_check_port         = 8080
health_check_request_path = "/health"

# Backend 설정
backend_protocol  = "HTTP"
backend_port_name = "http"
backend_timeout   = 30
```

### Terraform 직접 사용

```hcl
module "web_lb" {
  source = "../../modules/load-balancer-layer"

  # Naming 변수
  project_name   = "my-game"
  environment    = "prod"
  organization   = "myorg"
  region_primary = "asia-northeast3"
  region_backup  = "us-central1"

  # LB 기본 설정
  project_id = "my-project-id"
  lb_type    = "http"
  region     = "asia-northeast3"

  # Auto Instance Groups
  auto_instance_groups = {
    "web-ig-1" = "projects/my-project/zones/asia-northeast3-a/instanceGroups/web-ig-1"
    "web-ig-2" = "projects/my-project/zones/asia-northeast3-b/instanceGroups/web-ig-2"
  }

  # Health Check
  health_check_port         = 80
  health_check_request_path = "/health"

  # Backend Service
  backend_protocol  = "HTTP"
  backend_port_name = "http"
  backend_timeout   = 30

  # SSL (HTTPS LB인 경우)
  use_ssl          = true
  ssl_certificates = ["projects/my-project/global/sslCertificates/my-cert"]
}
```

## 변수 (주요)

### Naming 관련
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `project_name` | string | Y | - | 프로젝트 이름 |
| `environment` | string | N | prod | 환경 (prod, dev 등) |
| `organization` | string | N | myorg | 조직 접두어 |
| `region_primary` | string | N | us-central1 | Primary 리전 |
| `region_backup` | string | N | us-east1 | Backup 리전 |

### Load Balancer 기본
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `project_id` | string | Y | - | GCP 프로젝트 ID |
| `lb_type` | string | Y | - | LB 타입 (http, internal, internal_classic) |
| `region` | string | N | us-central1 | 리전 |

### Auto Instance Groups
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `auto_instance_groups` | map(string) | N | {} | 자동 추가할 Instance Group 맵 |
| `auto_backend_balancing_mode` | string | N | UTILIZATION | Balancing 모드 |
| `auto_backend_capacity_scaler` | number | N | 1.0 | 용량 스케일러 |
| `auto_backend_max_utilization` | number | N | 0.8 | 최대 사용률 (80%) |

### Backend Service
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `backends` | list(object) | N | [] | 수동 추가 Backend 리스트 |
| `backend_protocol` | string | N | HTTP | Backend 프로토콜 |
| `backend_port_name` | string | N | http | Backend 포트 이름 |
| `backend_timeout` | number | N | 30 | Backend 타임아웃 (초) |

### Health Check
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `create_health_check` | bool | N | true | Health Check 생성 여부 |
| `health_check_type` | string | N | HTTP | Health Check 타입 |
| `health_check_port` | number | N | 80 | Health Check 포트 |
| `health_check_request_path` | string | N | / | Health Check 경로 |

### SSL/TLS (HTTP(S) LB만)
| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `use_ssl` | bool | N | false | HTTPS 사용 여부 |
| `ssl_certificates` | list(string) | N | [] | SSL 인증서 리스트 |
| `ssl_policy` | string | N | "" | SSL 정책 |

전체 변수는 [variables.tf](./variables.tf)를 참조하세요.

## Outputs

| Output | 설명 |
|--------|------|
| `backend_service_id` | Backend Service ID |
| `health_check_id` | Health Check ID |
| `forwarding_rule_ip_address` | Load Balancer IP 주소 |
| `static_ip_address` | 고정 IP 주소 |
| `lb_type` | Load Balancer 타입 |

## 디렉토리 구조 예시

```
environments/LIVE/jsj-game-m/70-loadbalancers/
├── lobby/
│   ├── terragrunt.hcl          # source = "../../../../../modules/load-balancer-layer"
│   └── terraform.tfvars        # lobby 전용 설정
└── web/
    ├── terragrunt.hcl          # source = "../../../../../modules/load-balancer-layer"
    └── terraform.tfvars        # web 전용 설정
```

## vs load-balancer 모듈

| 특징 | load-balancer | load-balancer-layer |
|------|--------------|---------------------|
| **레벨** | Low-level | High-level wrapper |
| **네이밍** | 수동 지정 | naming 모듈 자동 생성 |
| **Instance Group** | 수동 추가 | auto_instance_groups로 자동 |
| **사용 대상** | 직접 Terraform 호출 | Terragrunt 환경 레이어 |
| **재사용성** | 범용적 | 프로젝트 표준 패턴 |

## 참고

- [load-balancer 모듈](../load-balancer/README.md) - 실제 LB 리소스를 생성하는 Low-level 모듈
- [naming 모듈](../naming/README.md) - 리소스 네이밍 규칙
