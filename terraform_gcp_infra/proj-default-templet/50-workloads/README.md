# 50-workloads 레이어
> Terragrunt: environments/LIVE/proj-default-templet/50-workloads/terragrunt.hcl


Compute Engine VM 세트(Instance Template + Managed Instance Group)를 배포하는 레이어입니다. naming 모듈을 활용해 인스턴스 이름, 태그, 라벨을 일관적으로 관리합니다.

## 주요 기능
- `modules/gce-vmset`을 이용해 지정된 수량의 VM 생성
- Shielded VM, OS Login, Preemptible 옵션 지원
- Startup script 및 서비스 계정, 네트워크 태그 설정

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 다음 항목을 환경에 맞게 수정하세요.
   - `instance_count`, `machine_type`
   - `enable_public_ip`, `enable_os_login`, `preemptible`
   - `startup_script` (필요한 초기화 스크립트)
   - `service_account_email` (비워두면 naming 기반 기본 계정 사용)
   - `tags`, `labels`

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/50-workloads
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- 서브넷 또는 서비스 계정을 명시적으로 지정하지 않으면 naming 모듈이 제공하는 기본값을 사용합니다.
- LB 백엔드로 연결하려면 `70-loadbalancer` 레이어에서 동일한 인스턴스 그룹 Self Link를 참조하세요.
