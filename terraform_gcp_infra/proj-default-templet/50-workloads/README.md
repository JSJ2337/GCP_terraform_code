# 50-workloads 레이어
> Terragrunt: environments/LIVE/proj-default-templet/50-workloads/terragrunt.hcl


Compute Engine VM 인스턴스를 배포하는 레이어입니다. 두 가지 방식을 지원하여 간단한 경우부터 복잡한 구성까지 유연하게 대응할 수 있습니다.

## 주요 기능
- **두 가지 배포 방식 지원**:
  - **count 방식**: 모든 VM이 동일한 설정 (간단한 경우)
  - **for_each 방식** (권장): 각 VM마다 다른 호스트네임, 서브넷, 존, 설정 가능
- `modules/gce-vmset`을 이용한 VM 생성
- Shielded VM, OS Login, Preemptible 옵션 지원
- Startup script 및 서비스 계정, 네트워크 태그 설정
- **용도별 서브넷 배치**: 10-network에서 생성한 Web/App/DB 서브넷에 VM 분산 배치

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

## 배포 방식 선택

### 방법 1: count 방식 (간단한 경우)

**사용 시기**: 모든 VM이 동일한 설정일 때

```hcl
# terraform.tfvars
instance_count = 3
machine_type   = "e2-medium"
enable_public_ip = false
tags = ["web", "prod"]
```

- ✅ 간단함
- ❌ 모든 VM이 같은 서브넷, 같은 존
- ❌ 호스트네임 개별 설정 불가

### 방법 2: for_each 방식 (권장)

**사용 시기**: 각 VM마다 다른 설정이 필요할 때

```hcl
# terraform.tfvars
instance_count = 0  # count 방식 비활성화

instances = {
  "web-server-01" = {
    hostname             = "web-srv-01"
    subnetwork_self_link = "projects/your-project/regions/us-central1/subnetworks/project-prod-subnet-web"
    zone                 = "us-central1-a"
    machine_type         = "e2-small"
    enable_public_ip     = false
    tags                 = ["web", "frontend"]
    labels = {
      role = "web"
    }
    startup_script = <<-EOF
      #!/bin/bash
      apt-get update && apt-get install -y nginx
    EOF
  }

  "app-server-01" = {
    hostname             = "app-srv-01"
    subnetwork_self_link = "projects/your-project/regions/us-central1/subnetworks/project-prod-subnet-app"
    zone                 = "us-central1-b"
    machine_type         = "e2-medium"
    tags                 = ["app", "backend"]
  }

  "db-proxy-01" = {
    hostname             = "db-proxy-01"
    subnetwork_self_link = "projects/your-project/regions/us-central1/subnetworks/project-prod-subnet-db"
    zone                 = "us-central1-c"
    machine_type         = "e2-micro"
  }
}
```

- ✅ 각 VM마다 다른 호스트네임
- ✅ 각 VM마다 다른 서브넷 (Web/App/DB 분리)
- ✅ 각 VM마다 다른 존 (고가용성)
- ✅ 각 VM마다 다른 머신타입, 스타트업 스크립트

## 서브넷 Self Link 확인 방법

10-network 레이어에서 생성한 서브넷의 전체 경로:

```
projects/{project-id}/regions/{region}/subnetworks/{subnet-name}
```

**예시:**
- Web 서브넷: `projects/jsj-game-g/regions/asia-northeast3/subnetworks/game-g-prod-subnet-web`
- App 서브넷: `projects/jsj-game-g/regions/asia-northeast3/subnetworks/game-g-prod-subnet-app`
- DB 서브넷: `projects/jsj-game-g/regions/asia-northeast3/subnetworks/game-g-prod-subnet-db`

**Terragrunt로 확인:**
```bash
cd ../10-network
terragrunt output
# subnet_ids 출력에서 확인 가능
```

## Terragrunt 실행
```bash
cd environments/LIVE/proj-default-templet/50-workloads
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 설정 항목 설명

### 공통 설정 (기본값)
- `machine_type`: 머신 타입 (각 VM에서 override 가능)
- `enable_public_ip`: 외부 IP 할당 여부
- `enable_os_login`: Google Cloud OS Login 활성화
- `preemptible`: Spot VM 사용 여부 (비용 절감)
- `tags`: 방화벽 규칙 타겟팅용 네트워크 태그
- `labels`: 리소스 라벨링 (관리/비용 추적)

### VM별 개별 설정 (instances map)
- `hostname`: VM 내부 호스트네임 (선택)
- `subnetwork_self_link`: 배치할 서브넷 전체 경로 (**중요**)
- `zone`: 배치할 존 (고가용성 구성 시 분산 배치)
- `machine_type`: VM 타입 (기본값 override)
- `startup_script`: 초기화 스크립트 (각 VM마다 다른 작업 가능)
- `tags`: 추가 네트워크 태그
- `labels`: 추가 라벨

## 참고
- 서브넷 또는 서비스 계정을 명시적으로 지정하지 않으면 naming 모듈이 제공하는 기본값을 사용합니다.
- LB 백엔드로 연결하려면 `70-loadbalancer` 레이어에서 동일한 인스턴스 그룹 Self Link를 참조하세요.
- **보안 강화**: Web/App/DB 서브넷 분리로 각 계층 간 네트워크 격리 가능
- **고가용성**: 여러 존에 VM을 분산 배치하여 단일 장애 지점 제거

## 예제 참조
- count 방식 예제: `terraform.tfvars.example` 상단 참조
- for_each 방식 예제: `terraform.tfvars.example` 하단 주석 참조
- 실제 운영 예제: `environments/LIVE/jsj-game-g/50-workloads/terraform.tfvars`
