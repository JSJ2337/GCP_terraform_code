# GCE VM 세트 모듈

이 모듈은 일관된 구성으로 Google Compute Engine VM 인스턴스 세트를 생성하고 관리합니다.

## 기능

- **다중 인스턴스**: 단일 영역에 여러 동일한 인스턴스 생성
- **유연한 배치**: 두 가지 방식 지원
  - **count 방식**: 모든 VM이 동일한 설정 (간단한 경우)
  - **for_each 방식** (권장): 각 VM마다 다른 호스트네임, 서브넷, 존, 설정 가능
- **이미지 선택**: 사용자 정의 이미지 및 공개 이미지 제품군 지원 (전역 기본값 + 인스턴스별 override)
- **디스크 구성**: 부팅 디스크 크기 및 타입 구성 가능
- **네트워크 구성**: 비공개 또는 공개 IP 주소 지원
- **서비스 계정**: 사용자 정의 또는 기본 서비스 계정 연결
- **시작 스크립트**: 인스턴스 부팅 시 초기화 스크립트 실행 (`startup_script` 필드에 직접 문자열 삽입 또는 상위 레이어에서 `file()`로 전달)
- **선점형/스팟**: 비용 효율적인 선점형 인스턴스 지원 (자동 재시작 비활성화 및 유지보수 시 TERMINATE로 안전 설정)
- **OS 로그인**: SSH 액세스를 위한 Google Cloud OS 로그인 활성화
- **메타데이터 및 레이블**: 사용자 정의 인스턴스 메타데이터 및 레이블
- **네트워크 태그**: 방화벽 규칙 타겟팅을 위한 태그 적용
- **커스텀 호스트네임**: VM별로 독립적인 호스트네임 설정

## 사용법

### 방법 1: 기본 VM 세트 (count 방식)

모든 VM이 동일한 설정을 사용할 때 간단하게 사용:

```hcl
module "app_vms" {
  source = "../../modules/gce-vmset"

  project_id           = "my-project-id"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/my-subnet"

  instance_count = 3
  name_prefix    = "app-server"
  machine_type   = "e2-medium"
}

> 💡 상위 Terragrunt 레이어(예: `50-workloads`)에서는 `startup_script_file = "scripts/lobby.sh"`처럼 상대 경로만 선언하고, HCL에서 `startup_script = file("${path.module}/${cfg.startup_script_file}")`로 전달하는 패턴을 사용합니다.
```

### 방법 2: 개별 설정 VM (for_each 방식 - 권장)

각 VM마다 다른 호스트네임, 서브넷, 존, 설정이 필요할 때:

```hcl
module "app_vms" {
  source = "../../modules/gce-vmset"

  project_id = "my-project-id"

  # 기본값 (각 VM에서 override 가능)
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/default"
  machine_type         = "e2-medium"

  # VM별 개별 설정
  instances = {
    "web-server-01" = {
      hostname             = "web-srv-01"
      subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/web-subnet"
      zone                 = "us-central1-a"
      machine_type         = "e2-small"
      enable_public_ip     = true
      tags                 = ["web", "frontend"]
      labels = {
        role = "web"
      }
      startup_script = file("${path.module}/scripts/lobby.sh")
    }

    "app-server-01" = {
      hostname             = "app-srv-01"
      subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/app-subnet"
      zone                 = "us-central1-b"
      machine_type         = "e2-medium"
      enable_public_ip     = false
      tags                 = ["app", "backend"]
      labels = {
        role = "app"
      }
    }

    "db-proxy-01" = {
      hostname             = "db-proxy-01"
      subnetwork_self_link = "projects/my-project/regions/us-central1/subnetworks/db-subnet"
      zone                 = "us-central1-c"
      machine_type         = "e2-micro"
      image_family         = "ubuntu-2204-lts"
      image_project        = "ubuntu-os-cloud"
      tags                 = ["db-proxy"]
    }
  }
}
```

### 사용자 정의 구성이 있는 프로덕션 VM 세트

```hcl
module "prod_app_servers" {
  source = "../../modules/gce-vmset"

  project_id           = "prod-project-123"
  zone                 = "us-central1-a"
  subnetwork_self_link = "projects/prod-project-123/regions/us-central1/subnetworks/prod-subnet"

  instance_count = 5
  name_prefix    = "prod-app"
  machine_type   = "n2-standard-4"

  # 운영 체제
  boot_disk_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  boot_disk_size_gb = 50
  boot_disk_type    = "pd-balanced"

  # 네트워크 구성
  enable_public_ip = false  # 비공개 인스턴스만
  enable_os_login  = true   # OS 로그인 사용

  # 서비스 계정
  service_account_email = "app-sa@prod-project-123.iam.gserviceaccount.com"
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # 시작 스크립트
  startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
  EOF

  # 태그 및 레이블
  tags = ["app-server", "prod"]
  labels = {
    environment = "prod"
    tier        = "app"
    managed-by  = "terraform"
  }
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | 프로젝트 ID | `string` | n/a | ✅ |
| zone | 기본 존 (instances에서 override 가능) | `string` | n/a | ✅ |
| subnetwork_self_link | 기본 서브넷 self-link | `string` | n/a | ✅ |
| instance_count | count 방식 인스턴스 개수 (`instances`가 비어 있을 때만 적용) | `number` | `0` | ❌ |
| name_prefix | count 방식 인스턴스 이름 접두사 | `string` | `"gce-node"` | ❌ |
| machine_type | 기본 머신 타입 | `string` | `"e2-standard-2"` | ❌ |
| image_family | 기본 OS 이미지 패밀리 | `string` | `"debian-12"` | ❌ |
| image_project | 기본 이미지 프로젝트 | `string` | `"debian-cloud"` | ❌ |
| boot_disk_size_gb | 부팅 디스크 크기 (GB) | `number` | `20` | ❌ |
| boot_disk_type | 부팅 디스크 타입 | `string` | `"pd-balanced"` | ❌ |
| enable_public_ip | 기본 Public IP 할당 여부 | `bool` | `false` | ❌ |
| enable_os_login | OS Login 활성화 여부 | `bool` | `true` | ❌ |
| preemptible | Spot/선점형 인스턴스 사용 여부 | `bool` | `false` | ❌ |
| service_account_email | 기본 서비스 계정 이메일 (미지정 시 Compute 기본 SA) | `string` | `""` | ❌ |
| service_account_scopes | 서비스 계정 스코프 | `list(string)` | `["https://www.googleapis.com/auth/cloud-platform"]` | ❌ |
| startup_script | 기본 startup script (문자열) | `string` | `""` | ❌ |
| metadata | 공통 메타데이터 | `map(string)` | `{}` | ❌ |
| tags | 공통 네트워크 태그 | `list(string)` | `[]` | ❌ |
| labels | 공통 라벨 | `map(string)` | `{}` | ❌ |
| instances | for_each 인스턴스 맵. `hostname`, `zone`, `machine_type`, `subnetwork_self_link`, `enable_public_ip`, `enable_os_login`, `preemptible`, `startup_script`, `metadata`, `tags`, `labels`, `boot_disk_size_gb`, `boot_disk_type`, `image_family`, `image_project`, `service_account_email` 등을 인스턴스별로 override | `map(object(...))` | `{}` | ❌ |

## 출력 값

| 이름 | 설명 |
|------|------|
| instance_names | 생성된 인스턴스 이름 목록 |
| instance_self_links | 인스턴스 셀프 링크 목록 |
| instance_internal_ips | 인스턴스 내부 IP 주소 목록 |
| instance_external_ips | 인스턴스 외부 IP 주소 목록 (있는 경우) |

## 일반적인 머신 타입

### 범용
- `e2-micro` - 0.25-2 vCPU, 1 GB RAM (무료 등급)
- `e2-small` - 0.5-2 vCPU, 2 GB RAM
- `e2-medium` - 1-2 vCPU, 4 GB RAM
- `e2-standard-4` - 4 vCPU, 16 GB RAM

### 계산 최적화
- `c2-standard-4` - 4 vCPU, 16 GB RAM
- `c2-standard-8` - 8 vCPU, 32 GB RAM

### 메모리 최적화
- `n2-highmem-4` - 4 vCPU, 32 GB RAM
- `n2-highmem-8` - 8 vCPU, 64 GB RAM

## 디스크 타입

- `pd-standard` - 표준 영구 디스크 (저렴, 낮은 성능)
- `pd-balanced` - 균형 잡힌 영구 디스크 (권장)
- `pd-ssd` - SSD 영구 디스크 (고성능)

## 모범 사례

1. **네트워크 보안**: 프로덕션에는 공개 IP 사용 안 함, IAP 또는 VPN 사용
2. **OS 로그인**: SSH 키 대신 IAM 기반 액세스를 위해 활성화
3. **서비스 계정**: VM마다 최소 권한 서비스 계정 사용
4. **태그**: 방화벽 규칙 및 조직을 위한 일관된 네트워크 태그
5. **레이블**: 비용 추적 및 관리를 위한 리소스 레이블
6. **시작 스크립트**: 멱등성 및 오류 처리 보장
7. **모니터링**: 로깅 및 모니터링 에이전트 설치
8. **Spot 주의**: `preemptible = true`일 때는 자동 재시작이 비활성화되고 유지보수 시 종료되도록 고정되므로 트래픽 분산/복구 정책을 반드시 준비하세요.

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30

## 필요한 권한

- `roles/compute.instanceAdmin.v1` - VM 인스턴스 생성 및 관리
- `roles/iam.serviceAccountUser` - 서비스 계정 사용

## 참고사항

- 인스턴스 이름은 `{name_prefix}-{index}` 형식입니다
- 시작 스크립트는 인스턴스 메타데이터에 저장됩니다
- 선점형 VM은 저렴하지만 언제든지 중단될 수 있습니다
- 영역 변경은 VM 재생성이 필요합니다
- VM 삭제 시 부팅 디스크도 자동으로 삭제됩니다
