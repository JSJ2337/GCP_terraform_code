# 65-cache 레이어
> Terragrunt: environments/LIVE/jsj-game-l/65-cache/terragrunt.hcl


Google Cloud Memorystore for Redis(Standard HA) 인스턴스를 배포합니다. 10-network 레이어가 생성한 전용 VPC에 프라이빗으로 연결하며, naming 모듈 규칙을 따라 일관된 리소스 이름과 라벨을 부여합니다.

## 주요 기능
- Standard HA Redis 인스턴스 생성 (Primary + Replica 자동 구성)
- VPC Direct Peering 기반 프라이빗 접속
- 유지보수 창, Redis 버전, 메모리 용량 등 파라미터화
- naming 모듈 공통 라벨/태그 자동 적용

## 입력 값 준비
1. 예시 파일 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 필수 수정 항목:
   - `project_id`
   - (선택) `region` — Terragrunt가 기본으로 `region_primary`를 주입하므로 필요할 때만 주석을 해제하고 값을 지정
   - `alternative_location_id` 또는 `alternative_location_suffix` (같은 리전 내 다른 존)
   - `memory_size_gb` (1~300GB 범위)
   - 필요 시 `authorized_network` (비워두면 템플릿 VPC 자동 사용)

> ℹ️ Standard HA 티어는 대체 존을 지정해야 합니다. Google Cloud 콘솔에서 사용 가능한 존을 확인한 뒤 설정하세요.

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/65-cache
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- Redis 엔드포인트는 Private IP만 제공되므로 GCE/GKE 등 동일 VPC 내 리소스에서만 접근 가능합니다.
- Memorystore는 기본적으로 백업 기능이 없으니, 데이터 보존이 필요한 경우 애플리케이션 레벨 스냅샷/복제 전략을 함께 마련하세요.
- `alternative_location_suffix`를 사용하면 리전 값만으로 이중화 존을 자동 산출할 수 있습니다. 직접 존을 지정하고 싶다면 `alternative_location_id`를 입력하세요.
- Enterprise 티어 기능(암호화, 자동 백업 등)이 필요하면 모듈 입력값(`tier`, `transit_encryption_mode`)을 조정하세요.
