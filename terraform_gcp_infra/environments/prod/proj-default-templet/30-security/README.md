# 30-security 레이어

프로젝트 수준 IAM 바인딩과 서비스 계정 생성을 담당합니다. `modules/naming`과 연동하여 일관된 서비스 계정 명명 규칙을 유지합니다.

## 주요 기능
- IAM 역할을 사용자/그룹/서비스 계정에 부여
- naming 모듈 기반 기본 서비스 계정(compute, monitoring, deployment) 자동 생성
- 공통 라벨/설명을 일괄 적용

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 필수 수정 항목:
   - `bindings`: 프로젝트 역할과 멤버 리스트 (예: viewer, logging.viewer 등)
   - `create_service_accounts`: naming 규칙을 따라 기본 서비스 계정을 만들지 여부
   - `service_accounts`: 직접 커스텀 서비스 계정이 필요하면 리스트에 추가

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/30-security
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- `modules/naming`이 `sa_name_prefix`와 공통 라벨을 제공하므로, 커스텀 서비스 계정을 추가할 때에도 동일한 규칙으로 작성하는 것을 권장합니다.
- IAM 적용 시 조직 정책이나 기존 바인딩과 충돌하지 않는지 확인하세요.
