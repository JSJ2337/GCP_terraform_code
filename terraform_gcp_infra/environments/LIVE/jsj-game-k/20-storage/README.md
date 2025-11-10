# 20-storage 레이어
> Terragrunt: environments/LIVE/jsj-game-k/20-storage/terragrunt.hcl


게임 자산, 로그, 백업 등 용도별 GCS 버킷을 일괄 관리합니다. `modules/gcs-root`와 `modules/naming`을 이용해 일관된 이름과 라벨을 적용합니다.

## 주요 기능
- 자산(`assets`), 로그(`logs`), 백업(`backups`) 버킷 생성
- 버킷 버전 관리, 수명 주기(Lifecycle), CORS, IAM 바인딩 설정
- 조직 정책(Uniform bucket-level access, Public Access Prevention) 적용
- (선택) CMEK 기반 암호화 키 사용

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 수정해야 할 주요 항목:
   - `default_labels`: 공통 라벨 (naming 모듈과 병합됨)
   - `assets_*`, `logs_*`, `backups_*` 섹션: 용도별 버킷 정책 정의
   - `kms_key_name`: 필요 시 조직의 KMS 키로 변경
   - `assets_cors_rules` 등 CORS/라이프사이클 정책

버킷 이름은 naming 모듈이 자동으로 생성하므로 별도 지정이 필요 없습니다.

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/20-storage
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 기타
- 로그 버킷을 중앙 조직 로그 프로젝트로 전송하려면 40-observability 레이어의 log sink와 함께 구성하세요.
- 버킷 정책 변경 시 기존 객체에 영향이 없는지 검토 후 apply 하십시오.
- `retention_policy_days`, `public_access_prevention` 등 선택 입력을 비워두면 Terragrunt 기본값(0, `"enforced"`)이 적용되며, 필요 시에만 값을 지정하세요.
