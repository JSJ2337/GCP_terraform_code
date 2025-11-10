# 70-loadbalancer 레이어
> Terragrunt: environments/LIVE/jsj-game-k/70-loadbalancer/terragrunt.hcl


HTTP(S) 및 내부 로드밸런서를 비롯해 다양한 GCP Load Balancer 구성을 담당합니다. 백엔드 인스턴스 그룹을 연결하고 헬스 체크, CDN, IAP, SSL 등을 설정할 수 있습니다.

## 주요 기능
- 외부 HTTP(S) Load Balancer
- 내부 HTTP(S) Load Balancer
- 내부 TCP/UDP Load Balancer (Classic)
- 외부/내부 헬스 체크, Cloud CDN, Identity-Aware Proxy, SSL 인증서 연동

## 입력 값 준비
1. `terraform.tfvars.example` 복사:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. 주요 항목 설명:
   - `lb_type`: `http`, `internal`, `internal_classic` 중 선택
   - `backends`: 인스턴스 그룹 self link 및 용량 설정
   - `create_health_check`, `health_check_*`: 헬스 체크 타입과 경로
   - `enable_cdn`, `enable_iap`, `use_ssl`: 옵션 기능 토글
   - 내부 LB일 경우 `network`, `subnetwork`, `forwarding_rule_ports` 지정

## Terragrunt 실행
```bash
cd environments/prod/proj-default-templet/70-loadbalancer
terragrunt init   --non-interactive
terragrunt plan   --non-interactive
terragrunt apply  --non-interactive
```

## 참고
- 외부 HTTPS LB를 구성할 경우 SSL 인증서(Google Managed 또는 self-managed)를 미리 준비하세요.
- 내부 LB는 네트워크와 서브넷을 명시적으로 지정해야 하며, 백엔드 인스턴스 그룹이 해당 서브넷에 존재해야 합니다.
- Cloud CDN 또는 IAP를 활성화하면 추가 비용/설정이 필요하므로 운영 정책에 맞게 조정하세요.
