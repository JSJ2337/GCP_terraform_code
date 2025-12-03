# Bootstrap - GCP 기본 인프라 및 Terraform 상태 관리

이 디렉토리는 GCP 인프라의 기반이 되는 관리용 프로젝트, 네트워크, 스토리지, Jenkins VM을 생성합니다.

## 레이어 구조

Bootstrap은 4개의 Terragrunt 레이어로 구성되어 있습니다:

```text
bootstrap/
├── root.hcl                    # Terragrunt 공통 설정 (backend, provider)
├── common.bootstrap.tfvars     # 공통 변수 (org_id, billing, labels)
│
├── 00-foundation/              # 기본 인프라
│   ├── main.tf                 # GCP 폴더, 프로젝트, API, SA, IAM
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── terragrunt.hcl
│
├── 10-network/                 # 네트워크
│   ├── main.tf                 # VPC, Subnet, Cloud NAT, Firewall
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── terragrunt.hcl
│
├── 20-storage/                 # 스토리지
│   ├── main.tf                 # Terraform State GCS 버킷
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── terragrunt.hcl
│
└── 50-compute/                 # 컴퓨트
    ├── main.tf                 # Jenkins VM
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── terragrunt.hcl
```

## 의존성 흐름

```text
00-foundation (독립)
    │
    ├── management_project_id
    ├── management_project_number
    └── jenkins_service_account_email
         │
         ▼
10-network ─────────────────────┐
    │                           │
    ├── vpc_self_link           │
    └── subnet_self_link        │
         │                      │
         ▼                      ▼
20-storage              50-compute (Jenkins VM)
```

## Projects 구조 (다중 프로젝트 관리)

Bootstrap은 `common.hcl`의 **projects 맵**을 통해 여러 프로젝트를 중앙에서 관리합니다.

### common.hcl - Projects 맵 구조

```hcl
locals {
  projects = {
    gcby = {
      project_id   = "gcp-gcby"
      environment  = "live"
      vpc_name     = "gcby-live-vpc"
      network_url  = "projects/gcp-gcby/global/networks/gcby-live-vpc"

      # PSC Endpoint IP (mgmt VPC용)
      psc_ips = {
        cloudsql = "10.250.20.20"
        redis    = "10.250.20.101"
      }

      # VM Static IP
      vm_ips = {
        gs01 = "10.10.11.3"
        gs02 = "10.10.11.6"
      }

      # Dependency 경로
      database_path = "../../environments/LIVE/gcp-gcby/60-database"
      cache_path    = "../../environments/LIVE/gcp-gcby/65-cache"
    }
    # 새 프로젝트 추가 시 여기에 추가
  }
}
```

### 자동 생성되는 리소스

| 리소스 타입 | 생성 위치 | 동작 방식 |
|------------|----------|----------|
| **VPC Peering** | 10-network/main.tf | `for_each`로 모든 프로젝트 자동 순회 |
| **PSC Endpoints** | 10-network/terragrunt.hcl | projects.*.psc_ips에서 동적 생성 |
| **DNS 레코드 (VM)** | 12-dns/layer.hcl | projects.*.vm_ips에서 동적 생성 |
| **DNS 레코드 (PSC)** | 12-dns/layer.hcl | projects.*.psc_ips에서 동적 생성 |

### 새 프로젝트 추가 방법

**예시: abc 프로젝트 추가**

#### 1. common.hcl에 프로젝트 추가 (5분)

```hcl
projects = {
  gcby = { ... }  # 기존
  abc = {         # 신규
    project_id   = "gcp-abc"
    environment  = "live"
    vpc_name     = "abc-live-vpc"
    network_url  = "projects/gcp-abc/global/networks/abc-live-vpc"
    psc_ips = {
      cloudsql = "10.250.21.20"
      redis    = "10.250.21.101"
    }
    vm_ips = {
      web01 = "10.20.11.10"
    }
    database_path = "../../environments/LIVE/gcp-abc/60-database"
    cache_path    = "../../environments/LIVE/gcp-abc/65-cache"
  }
}
```

#### 2. 10-network/terragrunt.hcl에 Dependency 추가 (10분)

**⚠️ 주의: Terragrunt 제약사항**
- `locals` 블록에서는 `dependency` 참조 불가 (다른 local 변수만 참조 가능)
- PSC Endpoints는 **inputs 블록**에서 생성해야 함

```hcl
# A) Dependencies 블록 추가
dependency "abc_database" {
  config_path = local.common_vars.locals.projects.abc.database_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-cloudsql"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
dependency "abc_cache" {
  config_path = local.common_vars.locals.projects.abc.cache_path
  mock_outputs = {
    psc_service_attachment_link = "projects/mock/regions/us-west1/serviceAttachments/mock-abc-redis"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# B) inputs 블록의 psc_endpoints에 추가 (dependency 참조는 inputs에서만 가능)
inputs = {
  psc_endpoints = merge(
    # gcby 프로젝트 (기존)
    {
      "gcby-cloudsql" = { ... }
      "gcby-redis" = { ... }
    },
    # abc 프로젝트 (신규 추가)
    {
      "abc-cloudsql" = {
        region                    = "us-west1"
        ip_address                = local.projects.abc.psc_ips.cloudsql
        target_service_attachment = dependency.abc_database.outputs.psc_service_attachment_link
        allow_global_access       = true
      }
      "abc-redis" = {
        region                    = "us-west1"
        ip_address                = local.projects.abc.psc_ips.redis
        target_service_attachment = dependency.abc_cache.outputs.psc_service_attachment_link
        allow_global_access       = true
      }
    }
  )
}
```

#### 3. 자동 반영 (추가 작업 없음!)

- ✅ VPC Peering `mgmt ↔ abc` 자동 생성
- ✅ DNS 레코드 `abc-web01`, `abc-live-gdb-m1`, `abc-live-redis` 자동 생성
- ✅ PSC Endpoints 자동 생성

**상세 가이드**: [docs/guides/adding-new-project.md](../docs/guides/adding-new-project.md)

---

## 각 레이어 상세

### 00-foundation (기본 인프라)

| 리소스 | 설명 |
|--------|------|
| GCP 폴더 구조 | games/, games2/ → kr-region/, us-region/ → LIVE/, Staging/, GQ-dev/ |
| 관리 프로젝트 | `jsj-system-mgmt` (deletion_policy: PREVENT) |
| API 활성화 | storage, IAM, billing, compute, servicenetworking |
| Service Account | `jenkins-terraform-admin` |
| IAM 권한 | 조직/폴더/청구계정 레벨 권한 (옵션) |

### 10-network (네트워크)

| 리소스 | 설명 |
|--------|------|
| VPC | `delabs-gcp-mgmt-vpc` (auto_create_subnetworks: false) |
| Primary Subnet | `10.250.10.0/24` (asia-northeast3, private_ip_google_access: true) |
| us-west1 Subnet | `10.250.20.0/24` (PSC Endpoint용) |
| Cloud Router | 리전별 NAT용 라우터 (asia-northeast3, us-west1) |
| Cloud NAT | 리전별 아웃바운드 인터넷 액세스 |
| Firewall | IAP SSH, Jenkins 8080/443, 내부 통신 |
| PSC Endpoints | Cross-Project Cloud SQL/Redis 접근용 (Global Access 지원) |
| VPC Peering | 모든 프로젝트 VPC와 자동 피어링 (common.hcl의 projects 기반) |

**다중 프로젝트 지원 (일반화 구조)**:
- VPC Peering: `for_each`로 모든 프로젝트 자동 생성
- PSC Endpoints: projects 구조에서 동적 추출
- Dependency: 각 프로젝트의 Database/Cache 경로 참조

### 20-storage (스토리지)

| 리소스 | 설명 |
|--------|------|
| tfstate_prod | `jsj-terraform-state-prod` (versioning, lifecycle) |
| tfstate_dev | `jsj-terraform-state-dev` (옵션) |
| artifacts | `jsj-build-artifacts` (옵션) |

### 50-compute (컴퓨트)

| 리소스 | 설명 |
|--------|------|
| Jenkins VM | Debian 12, e2-medium, SSD 50GB |
| 자동 설치 | Java 17, Jenkins, Terraform, Terragrunt, gcloud CLI |
| 네트워크 태그 | `jenkins`, `allow-ssh` |
| 고정 IP | 옵션 (create_static_ip) |
| 데이터 디스크 | 옵션 (create_data_disk) |

## 사용 방법

### 1. 사전 준비

```bash
# GCP 인증
gcloud auth application-default login

# 조직 ID 확인
gcloud organizations list
```

### 2. 공통 설정 수정

`common.bootstrap.tfvars`:

```hcl
organization_id         = "REDACTED_ORG_ID"
billing_account         = "REDACTED_BILLING_ACCOUNT"
management_project_id   = "jsj-system-mgmt"
management_project_name = "jsj-system-mgmt"
```

### 3. 전체 배포 (Terragrunt)

```bash
cd bootstrap

# 전체 레이어 한 번에 배포
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

### 4. 개별 레이어 배포

```bash
# 순서대로 배포
cd 00-foundation && terragrunt apply
cd ../10-network && terragrunt apply
cd ../20-storage && terragrunt apply
cd ../50-compute && terragrunt apply
```

### 5. Jenkins 접속

```bash
# SSH 접속 (IAP 터널링)
cd 50-compute
terragrunt output -raw jenkins_ssh_command

# 웹 UI URL
terragrunt output -raw jenkins_web_url

# 초기 비밀번호 확인 (VM 내에서)
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 주요 Output

### 00-foundation

```bash
terragrunt output management_project_id
terragrunt output jenkins_service_account_email
terragrunt output environment_folder_ids
```

### 10-network

```bash
terragrunt output vpc_self_link
terragrunt output subnet_self_link
terragrunt output nat_name
```

### 20-storage

```bash
terragrunt output tfstate_prod_bucket_name
terragrunt output tfstate_prod_bucket_url
```

### 50-compute

```bash
terragrunt output jenkins_instance_name
terragrunt output jenkins_external_ip
terragrunt output jenkins_ssh_command
terragrunt output jenkins_web_url
```

## 옵션 플래그

### 00-foundation (terraform.tfvars)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `manage_folders` | `true` | GCP 폴더 구조 자동 생성 |
| `manage_org_iam` | `false` | 조직 IAM 자동 관리 |
| `enable_billing_account_binding` | `false` | Billing IAM 자동 관리 |

### 10-network (terraform.tfvars)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `subnet_cidr` | `10.0.0.0/24` | 서브넷 CIDR |
| `jenkins_allowed_cidrs` | `["0.0.0.0/0"]` | Jenkins 접근 허용 IP |

### 20-storage (terraform.tfvars)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `create_dev_bucket` | `false` | Dev 버킷 생성 |
| `create_artifacts_bucket` | `false` | 아티팩트 버킷 생성 |

### 50-compute (terraform.tfvars)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `jenkins_machine_type` | `e2-medium` | VM 타입 |
| `jenkins_disk_size` | `50` | 디스크 크기 (GB) |
| `assign_external_ip` | `true` | 외부 IP 할당 |
| `create_static_ip` | `false` | 고정 IP 생성 |
| `create_data_disk` | `false` | 추가 데이터 디스크 |
| `deletion_protection` | `true` | 삭제 방지 |

## 다른 프로젝트에서 State 참조

```hcl
# terragrunt.hcl
remote_state {
  backend = "gcs"
  config = {
    bucket   = "jsj-terraform-state-prod"
    prefix   = "proj-game-a/00-project"
    project  = "jsj-system-mgmt"
    location = "US"
  }
}
```

## Jenkins Service Account 권한 설정

### 자동 설정 (terraform.tfvars)

```hcl
manage_org_iam                 = true   # 조직 IAM
enable_billing_account_binding = true   # Billing IAM
```

### 수동 설정 (권장)

```bash
# 조직 레벨 권한
gcloud organizations add-iam-policy-binding REDACTED_ORG_ID \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.projectCreator"

gcloud organizations add-iam-policy-binding REDACTED_ORG_ID \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"

# Billing 계정 권한
gcloud beta billing accounts add-iam-policy-binding REDACTED_BILLING_ACCOUNT \
    --member="serviceAccount:jenkins-terraform-admin@jsj-system-mgmt.iam.gserviceaccount.com" \
    --role="roles/billing.user"
```

## 주의사항

- **삭제 방지**: 프로젝트와 버킷에 삭제 보호가 설정되어 있습니다
- **State 백업**: GCS 버킷에 versioning이 활성화되어 있어 최근 10개 버전이 보관됩니다
- **Jenkins 초기화**: VM 생성 후 startup script 완료까지 5-10분 소요됩니다
- **보안**: 운영 환경에서는 `jenkins_allowed_cidrs`를 제한하세요

### Terragrunt 제약사항 (중요!)

**10-network/terragrunt.hcl 수정 시 주의**:
- `locals` 블록에서는 `dependency.*` 참조 불가
- PSC Endpoints는 반드시 `inputs` 블록에서 생성
- `locals` 블록은 파일당 하나만 허용

**블록별 참조 규칙**:
| 블록 | 참조 가능 | 참조 불가 |
|------|---------|---------|
| `locals` | local 변수, read_terragrunt_config() | dependency outputs |
| `inputs` | local 변수, dependency outputs | - |

**잘못된 예시** (에러 발생):
```hcl
locals {
  psc_endpoints = {
    "gcby-cloudsql" = {
      target_service_attachment = dependency.gcby_database.outputs...  # ❌ 에러!
    }
  }
}
```

**올바른 예시**:
```hcl
inputs = {
  psc_endpoints = {
    "gcby-cloudsql" = {
      target_service_attachment = dependency.gcby_database.outputs...  # ✅ 정상
    }
  }
}
```

## 기존 단일 파일 구조 (레거시)

기존 `bootstrap/main.tf`, `variables.tf`, `outputs.tf` 파일은 레거시 호환성을 위해 유지됩니다.
새로운 배포는 레이어 구조 (`00-foundation`, `10-network`, `20-storage`, `50-compute`)를 사용하세요.
