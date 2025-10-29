# GCE VM 세트 모듈

이 모듈은 일관된 구성으로 Google Compute Engine VM 인스턴스 세트를 생성하고 관리합니다.

## 기능

- **다중 인스턴스**: 단일 영역에 여러 동일한 인스턴스 생성
- **이미지 선택**: 사용자 정의 이미지 및 공개 이미지 제품군 지원
- **디스크 구성**: 부팅 디스크 크기 및 타입 구성 가능
- **네트워크 구성**: 비공개 또는 공개 IP 주소 지원
- **서비스 계정**: 사용자 정의 또는 기본 서비스 계정 연결
- **시작 스크립트**: 인스턴스 부팅 시 초기화 스크립트 실행
- **선점형/스팟**: 비용 효율적인 선점형 인스턴스 지원
- **OS 로그인**: SSH 액세스를 위한 Google Cloud OS 로그인 활성화
- **메타데이터 및 레이블**: 사용자 정의 인스턴스 메타데이터 및 레이블
- **네트워크 태그**: 방화벽 규칙 타겟팅을 위한 태그 적용

## 사용법

### 기본 VM 세트

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
| project_id | 프로젝트 ID | `string` | n/a | yes |
| zone | VM을 생성할 영역 | `string` | n/a | yes |
| subnetwork_self_link | 서브넷 셀프 링크 | `string` | n/a | yes |
| instance_count | 생성할 인스턴스 수 | `number` | `1` | no |
| name_prefix | 인스턴스 이름 접두사 | `string` | n/a | yes |
| machine_type | 머신 타입 | `string` | `"e2-micro"` | no |
| boot_disk_size_gb | 부팅 디스크 크기 (GB) | `number` | `10` | no |
| boot_disk_type | 부팅 디스크 타입 | `string` | `"pd-standard"` | no |
| boot_disk_image | 부팅 디스크 이미지 | `string` | `"debian-cloud/debian-11"` | no |
| enable_public_ip | 공개 IP 할당 | `bool` | `false` | no |
| enable_os_login | OS 로그인 활성화 | `bool` | `false` | no |
| preemptible | 선점형 VM | `bool` | `false` | no |
| startup_script | 시작 스크립트 | `string` | `""` | no |
| service_account_email | 서비스 계정 이메일 | `string` | `""` | no |
| service_account_scopes | 서비스 계정 범위 | `list(string)` | `[]` | no |
| tags | 네트워크 태그 | `list(string)` | `[]` | no |
| labels | 리소스 레이블 | `map(string)` | `{}` | no |

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
