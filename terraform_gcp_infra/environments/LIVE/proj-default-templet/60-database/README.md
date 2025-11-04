# 60-database 레이어

Cloud SQL(MySQL) 인스턴스를 Private IP로 배포하고, 백업/로깅/Query Insights를 구성합니다. 10-network 레이어가 제공하는 Service Networking 연결을 활용합니다.

## 주요 기능
- MySQL 인스턴스 생성 (ZONAL/REGIONAL HA 선택)
- 자동 백업, PITR, 읽기 복제본 설정
- 느린 쿼리 로그 및 Cloud Logging 통합
- Private IP + Authorized network 구성

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 필수 수정 항목:
   - `project_id`, `region`
   - `tier`, `availability_type`
   - `private_network` (비워두면 naming 모듈의 VPC를 자동 사용)
   - DB/사용자 목록(`databases`, `users`)
   - 백업/로깅 정책 (`backup_*`, `enable_slow_query_log` 등)

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
- Query Insights나 일반 쿼리 로그는 비용에 영향을 줄 수 있으니 운영 환경에 맞게 조정하세요.
