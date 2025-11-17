# 60-database 레이어
> Terragrunt: environments/LIVE/jsj-game-m/60-database/terragrunt.hcl


Cloud SQL(MySQL) 인스턴스를 Private IP로 배포하고, 백업/로깅/Query Insights를 구성합니다. 10-network 레이어가 제공하는 Service Networking 연결을 활용합니다. 기본 예제는 고가용성(REGIONAL)을 유지하되 삭제 보호는 비활성화되어 있어 언제든지 destroy가 가능합니다.

## 주요 기능
- MySQL 인스턴스 생성 (ZONAL/REGIONAL HA 선택)
- 자동 백업, PITR, 읽기 복제본 설정 (복제본별 디스크/네트워크/유지보수 옵션 지원)
- 느린 쿼리 로그 및 Cloud Logging 통합
- Private IP + Authorized network 구성

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 필수 수정 항목:
   - (선택) `region` — Terragrunt가 기본으로 `region_primary`를 주입하므로 필요 시에만 주석을 해제하고 값을 지정
   - `tier`, `availability_type` (운영 기본은 `REGIONAL`)
   - `private_network` (비워두면 naming 모듈의 VPC를 자동 사용)
   - DB/사용자 목록(`databases`, `users`)
   - 백업/로깅 정책 (`backup_*`, `enable_slow_query_log` 등)
   - 읽기 복제본이 필요하면 `read_replicas` 맵에 리전/머신 타입과 선택 옵션(디스크/네트워크/라벨 등)을 정의

> ⚠️ 비밀번호는 Secret Manager 등 안전한 저장소를 사용하세요.

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/60-database
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- Private IP를 사용하려면 10-network 레이어에서 Service Networking 연결이 배포되어 있어야 합니다.
- 기본 `terraform.tfvars`는 삭제 보호를 `false`로 둡니다. 프로덕션 환경에서 보호가 필요하면 `deletion_protection = true`로 명시한 뒤 `apply`를 수행하세요.
- Query Insights나 일반 쿼리 로그는 비용에 영향을 줄 수 있으니 운영 환경에 맞게 조정하세요.
- 멀티 리전에 읽기 복제본을 둘 경우 `read_replicas`에서 각 복제본의 디스크/네트워크/유지보수 창을 개별 설정할 수 있습니다.
