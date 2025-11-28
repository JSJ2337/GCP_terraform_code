# 70-loadbalancers 그룹

이 디렉터리는 여러 종류의 Load Balancer 레이어를 모아둔 그룹입니다.
각 Load Balancer는 별도의 서브 디렉터리로 관리되며, 독립적으로 배포됩니다.

## 📁 구조

```
70-loadbalancers/
├── README.md              # 이 파일
├── example-http/          # HTTP(S) Load Balancer 예시
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terragrunt.hcl
│   ├── terraform.tfvars
│   └── terraform.tfvars.example
└── (추가 LB 폴더...)      # web/, api/, admin/ 등 필요에 따라 추가
```

## 🚀 사용법

### 1. 새 Load Balancer 추가

```bash
# example-http를 복사하여 새 LB 생성
cp -r example-http/ web/

# 설정 수정
cd web/
vim terraform.tfvars
```

### 2. Instance Group 정의 및 자동 연결

**terraform.tfvars에서 Instance Group 정의:**

```hcl
# 50-workloads의 VM을 Instance Group으로 그룹화
instance_groups = {
  "my-web-ig-a" = {
    instances   = ["my-web01"]  # 50-workloads에 정의된 VM 이름
    zone_suffix = "a"            # region_primary와 결합 (예: us-west1-a)
    named_ports = [{ name = "http", port = 80 }]
  }
  "my-web-ig-b" = {
    instances   = ["my-web02"]
    zone_suffix = "b"
    named_ports = [{ name = "http", port = 80 }]
  }
}
```

**VM 정보 자동 주입:**

`terragrunt.hcl`에서 50-workloads dependency를 통해 VM 정보 자동 로드:

```hcl
dependency "workloads" {
  config_path = "../../50-workloads"
}

inputs = merge(
  local.common_inputs,
  local.layer_inputs,
  local.lb_name_defaults,
  {
    # 50-workloads에서 VM 정보 자동으로 가져오기
    vm_details = try(dependency.workloads.outputs.vm_details, {})
  }
)
```

**자동 처리 로직:**

main.tf의 2단계 필터링:

```hcl
# 1단계: VM 존재 여부 확인 후 Instance Group 처리
_all_instance_groups = {
  for name, cfg in var.instance_groups :
  name => {
    resolved_instances = [
      for inst_name in cfg.instances : {
        name      = inst_name
        self_link = var.vm_details[inst_name].self_link
        zone      = var.vm_details[inst_name].zone
      }
      if contains(keys(var.vm_details), inst_name)  # VM 존재 확인
    ]
    # zone 자동 결정
    zone = ...
    named_ports = coalesce(cfg.named_ports, [])
  }
}

# 2단계: 빈 Instance Group 제거
processed_instance_groups = {
  for name, ig in local._all_instance_groups :
  name => ig
  if length(ig.resolved_instances) > 0  # VM이 있는 그룹만
}

# 3단계: Instance Group 리소스 생성
resource "google_compute_instance_group" "lb_instance_group" {
  for_each = local.processed_instance_groups
  # ...
}
```

### 3. 배포

```bash
cd web/
terragrunt init --non-interactive
terragrunt plan --non-interactive
terragrunt apply --non-interactive
```

## 📋 예시 시나리오

| 서브 디렉터리 | 설명 | 자동 연결되는 IG | 필터 패턴 |
|---------------|------|------------------|-----------|
| `web/` | 웹 서비스용 LB | `*-web-*` | `regexall("web", lower(name))` |
| `api/` | API 서버용 LB | `*-api-*` | `regexall("api", lower(name))` |
| `admin/` | 관리자 페이지용 LB | `*-admin-*` | `regexall("admin", lower(name))` |

## 📝 주요 설정 항목

`terraform.tfvars`에서 수정:

```hcl
# Load Balancer 기본 설정
lb_type = "http"                    # http, internal, internal_classic

# SSL/HTTPS 설정
use_ssl          = true
ssl_certificates = ["projects/my-project/global/sslCertificates/my-cert"]

# Health Check
health_check_port         = 80
health_check_request_path = "/health"

# Backend 설정
backend_protocol  = "HTTP"
backend_port_name = "http"
```

## ⚠️ 중요 사항

### VM과 Instance Group 자동 생성/삭제

**자동 생성:**
- ✅ VM이 생성되면 Instance Group에 자동 추가
- ✅ terraform.tfvars에 미리 정의해도 안전 (VM 없으면 대기)

**자동 삭제:**
- ✅ VM이 삭제되면 Instance Group에서 자동 제거
- ✅ Instance Group의 모든 VM이 삭제되면 Instance Group도 자동 삭제

**예시:**
```hcl
# terraform.tfvars에 정의
instance_groups = {
  "my-web-ig-a" = {
    instances = ["my-web01", "my-web02", "my-web03"]
  }
}

# Case 1: my-web03만 생성됨
# → Instance Group 생성, my-web03만 포함

# Case 2: my-web01, my-web02 삭제됨
# → Instance Group에서 자동 제거, my-web03만 남음

# Case 3: 모든 VM 삭제됨
# → Instance Group 자동 삭제
```

### ❌ vm_details.auto.tfvars 만들지 말 것!

**절대 금지:**
```bash
# ❌ 이런 파일 만들지 마세요!
echo 'vm_details = { ... }' > vm_details.auto.tfvars
```

**이유:**
- Terragrunt가 50-workloads dependency에서 자동으로 주입
- 수동 파일이 자동 값을 덮어씀
- VM 추가/삭제 시마다 수동 업데이트 필요 (자동화 의미 없음)

**올바른 방법:**
- terragrunt.hcl의 dependency 사용
- 아무 파일도 추가하지 않음

### Backend Cleanup 자동화 (중요!)

**문제:**
Instance Group 삭제 시 `resourceInUseByAnotherResource` 에러 발생
- Backend Service가 여전히 Instance Group 사용 중
- Terraform Core의 제약으로 삭제 순서 제어 불가 (GitHub Issue #6376)

**해결책:**
각 Load Balancer 폴더에 `cleanup_backends.sh` 스크립트 포함

**동작 원리:**
```bash
# Jenkins가 Phase 7 apply 전에 자동 실행
1. terraform.tfvars에서 정의된 instance_groups 파싱
2. Backend Service에 실제 연결된 backends 확인
3. Backend에는 있지만 tfvars에 없는 Instance Group 찾기
4. gcloud로 Backend Service에서 자동 제거
5. terragrunt apply 안전하게 실행
```

**⚠️ 중요: cleanup 스크립트가 작동하는 조건**

✅ **작동하는 경우**: terraform.tfvars에서 instance_group을 **직접 제거**했을 때
```hcl
# terraform.tfvars 수정 전
instance_groups = {
  "gcby-gs-ig-a" = { ... }
  "gcby-gs-ig-b" = { ... }
  "gcby-gs-ig-c" = { ... }  # ← 이것을 제거
}

# terraform.tfvars 수정 후
instance_groups = {
  "gcby-gs-ig-a" = { ... }
  "gcby-gs-ig-b" = { ... }
}
# → cleanup 스크립트가 gcby-gs-ig-c를 Backend에서 제거
```

❌ **작동하지 않는 경우**: VM 삭제로 인한 Instance Group 자동 삭제
```bash
# 1. 50-workloads에서 gcby-gs03 삭제
# 2. terraform.tfvars에는 gcby-gs-ig-c 그대로 유지
# → cleanup 스크립트: "tfvars에 있으니까 유지" (아무것도 안 함)
# → Terraform: "VM이 없으니 Instance Group 삭제" (2단계 필터링)
# → 에러 발생! (Backend에 여전히 붙어있음)

# 해결: terraform.tfvars에서도 gcby-gs-ig-c를 제거해야 함
```

**올바른 사용법:**
```bash
# 방법 1: Instance Group과 VM을 함께 제거 (권장)
1. 50-workloads에서 gcby-gs03 삭제
2. 70-loadbalancers terraform.tfvars에서도 gcby-gs-ig-c 제거
3. terragrunt apply
   → cleanup 스크립트가 자동으로 Backend에서 제거

# 방법 2: 수동 cleanup
cd 70-loadbalancers/gs
./cleanup_backends.sh  # 수동 실행
terragrunt apply
```

**Jenkins 자동화:**
- Jenkins 파이프라인이 Phase 7 apply 전에 자동 실행
- Single Layer 실행도 자동 지원
- 수동 개입 불필요

> **참고**: cleanup 스크립트는 Terraform의 근본적인 제약을 우회하는 베스트 프랙티스입니다.
> 자세한 내용은 [트러블슈팅 가이드](../../docs/troubleshooting/common-errors.md#backend-service-삭제-순서-문제)를 참조하세요.

---

### 중복 코드 구조

각 Load Balancer 폴더는 **독립적인 Terraform 파일**을 가집니다:
- ✅ 안정적 동작 (Terragrunt source 경로 문제 없음)
- ⚠️ 코드 중복 (main.tf, variables.tf, outputs.tf)
- 📝 수정 시 모든 폴더 업데이트 필요

> **참고**: Terragrunt의 source 메커니즘 제약으로 인해 공통 모듈화가 어렵습니다.
> 자세한 내용은 [트러블슈팅 가이드](../../docs/troubleshooting/common-errors.md#terragrunt-관련-오류)를 참조하세요.

### 새 LB 추가 체크리스트

- [ ] `example-http/`를 복사하여 새 폴더 생성
- [ ] Instance Group 필터 패턴 설정 (`terragrunt.hcl`)
- [ ] terraform.tfvars 수정:
  - [ ] Health Check 경로 (`health_check_request_path`)
  - [ ] SSL 인증서 (HTTPS 사용 시)
  - [ ] Backend 포트 (`backend_port_name`)
- [ ] `terraform init && terraform plan`으로 검증

## 🔗 의존성

- `00-project`: GCP 프로젝트
- `10-network`: VPC, 서브넷
- `50-workloads`: Instance Groups (Backend 연결)

## 📤 Outputs

각 LB는 다음을 출력합니다:
- `backend_service_id`: Backend Service ID
- `forwarding_rule_ip_address`: Load Balancer IP 주소
- `static_ip_address`: 고정 IP 주소
- `lb_type`: Load Balancer 타입

## 🔍 트러블슈팅

### SSL 인증서 오류

```bash
# Google Managed Certificate 생성
gcloud compute ssl-certificates create my-cert \
  --domains=example.com,www.example.com \
  --global
```

### Backend가 연결되지 않음

`terragrunt.hcl`의 필터 패턴 확인:
```bash
terragrunt console
> local.auto_instance_groups  # 출력 확인
```

## 📚 참고 문서

- [Load Balancer 모듈](../../modules/load-balancer/README.md)
- [Terragrunt 사용법](../../docs/guides/terragrunt-usage.md)
- [트러블슈팅](../../docs/troubleshooting/common-errors.md)
- [작업 이력 (2025-11-18)](../../docs/changelog/work_history/2025-11-18.md) - Load Balancer 구조 변경 이력
- [작업 이력 (2025-11-28)](../../docs/changelog/work_history/2025-11-28.md) - Instance Group 자동 처리 로직 개선
