# Quick Setup Guide (proj-default-templet 템플릿 기반 신규 프로젝트)

이 문서는 `terraform_gcp_infra/proj-default-templet/` 템플릿을 복제하여 새 환경을 빠르게 구성하기 위한 체크리스트입니다.

---

## 1. 준비 사항
- **새 프로젝트 코드**: 예) `proj-myservice-prod`
- **GCP Project ID / Billing Account**: 실제 배포 대상
- **Remote State 버킷/Prefix**: 중앙 상태 버킷(`delabs-terraform-state-prod`) 재사용, Prefix는 신규 환경명으로 변경
- **Notification Channel ID**: Cloud Monitoring 알림 채널(이메일·Slack 등) 사전 생성

---

## 2. 디렉터리 복제
```bash
cd terraform_gcp_infra
cp -R proj-default-templet environments/LIVE/proj-myservice-prod
```

---

## 3. 공통 설정 업데이트
| 파일 | 수정 항목 |
|------|-----------|
| `environments/LIVE/proj-myservice-prod/terragrunt.hcl` | `project_state_prefix`를 새 환경명으로 변경 |
| `environments/LIVE/proj-myservice-prod/common.naming.tfvars` | `project_id`, `project_name`, `environment`, `organization`, `region_*` 값을 신규 환경에 맞게 설정 |
| `environments/LIVE/proj-myservice-prod/common.override.tfvars` (선택) | 공통 오버라이드가 필요하면 사용 (기본은 비어 있음) |

---

## Terragrunt & Naming 구조 개요
- 각 레이어의 `terragrunt.hcl`은 `common.naming.tfvars`와 레이어 전용 `terraform.tfvars`를 자동 병합해 Terraform에 전달합니다.
- `common.naming.tfvars`에 적은 값(예: `project_id`, `region_primary`)은 naming 모듈을 통해 공통 리소스 이름·라벨·기본 존(`region_primary` + suffix)을 계산합니다.
- 레이어의 `terraform.tfvars`에 값이 비어 있으면 Terragrunt가 위 공통 값을 주입하고, 필요한 경우에만 해당 파일에서 override 하면 됩니다.
- 프로젝트마다 리전을 바꾸고 싶다면 해당 환경의 `common.naming.tfvars`에서 `region_primary`/`region_backup`만 수정하면 되고, naming 모듈이 자동으로 존까지 계산합니다.
- 특정 레이어에서 다른 리전·존을 써야 한다면 그 레이어 `terraform.tfvars`에 직접 값을 넣어 Terragrunt 입력을 덮어쓰면 됩니다.


---

## 4. 레이어별 필수 값
| 레이어 | 필수 수정 항목 | 파일 |
|--------|----------------|------|
| 00-project | `folder_id`, `billing_account`, 필요 API, 라벨 | `terraform.tfvars` |
| 10-network | VPC CIDR, Secondary 범위, Firewall 규칙 | `terraform.tfvars` |
| 20-storage | 버킷 위치/Storage Class, KMS 키, IAM | `terraform.tfvars` |
| 30-security | IAM 바인딩, 서비스 계정 생성 토글 | `terraform.tfvars` |
| 40-observability | `notification_channels`, 필요 시 Alert 임계값/정규식 | `terraform.tfvars` |
| 50-workloads | VM 갯수/머신타입/시작 스크립트, 네트워크 태그 | `terraform.tfvars` |
| 60-database | Cloud SQL Tier/지역/백업/로그 정책 | `terraform.tfvars` |
| 65-cache | Memorystore 메모리, 대체 존, 유지보수 창 | `terraform.tfvars` |
| 70-loadbalancer | LB 타입, 백엔드, Health Check, SSL/IAP | `terraform.tfvars` |

> 모든 레이어는 `terraform.tfvars.example`를 복사한 뒤 필수 항목을 채우면 됩니다.

---

## 5. Jenkinsfile 복사 (CI/CD 사용 시)
```bash
# Jenkinsfile 템플릿 복사
cp .jenkins/Jenkinsfile.template environments/LIVE/proj-myservice-prod/Jenkinsfile

# Jenkins Job 생성 시 Script Path 설정:
# environments/LIVE/proj-myservice-prod/Jenkinsfile
```

> 템플릿은 수정 없이 바로 사용 가능. TG_WORKING_DIR='.'로 자동 설정됨

---

## 6. Terragrunt 실행 순서
```bash
cd environments/LIVE/proj-myservice-prod
# 레이어별 배포 (예시)
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply --terragrunt-include-dir 00-project
terragrunt run-all apply --terragrunt-include-dir 10-network
# 이후 20 → 30 → 40 → 50 → 60 → 65 → 70 순서로 실행
```

> `run-all apply` 대신 단계적으로 `terragrunt -chdir=<layer> plan/apply`를 사용할 수도 있습니다.

---

## 7. 마무리 체크
- [ ] Cloud Monitoring Alert 정책이 새 프로젝트에서 정상 생성되었는지 확인
- [ ] 중앙 로그 싱크 사용 시 대상 버킷에 `log_sink_writer_identity` 서비스 계정 권한 부여
- [ ] Terraform/Terragrunt 상태 버킷에 새로운 Prefix가 생성되었는지 확인
- [ ] README/작업 내역(CHANGELOG 등)에 신규 환경 추가 기록

필요 시 `04_WORK_HISTORY.md`에 신규 배포 이력을 남기고, 후속 자동화(CI/CD, tfsec 등)를 연동해주세요.
