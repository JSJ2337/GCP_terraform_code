# 네트워크 문제 해결

네트워크 관련 문제 해결 가이드입니다.

## VPC 문제

### VPC 생성 실패
```bash
# 기존 VPC 확인
gcloud compute networks list --project=jsj-game-k

# 충돌 시 Import
terragrunt import google_compute_network.main \
    projects/jsj-game-k/global/networks/vpc-name
```

### 서브넷 중복
```bash
# 기존 서브넷 확인
gcloud compute networks subnets list \
    --network=vpc-main \
    --project=jsj-game-k

# CIDR 범위 충돌 확인
```

## 방화벽 규칙

### 규칙 충돌
```bash
# 기존 규칙 확인
gcloud compute firewall-rules list --project=jsj-game-k

# 수동 생성된 규칙 삭제
gcloud compute firewall-rules delete RULE_NAME --project=jsj-game-k

# Import
terragrunt import google_compute_firewall.rule \
    projects/jsj-game-k/global/firewalls/RULE_NAME
```

### 우선순위 문제
방화벽 규칙은 우선순위(숫자가 낮을수록 우선) 순으로 적용됩니다.
- 기본값: 1000
- 범위: 0-65535

## Private Service Connect

### PSC 연결 실패
```bash
# 기존 연결 확인
gcloud services vpc-peerings list \
    --network=vpc-main \
    --project=jsj-game-k
```

### IP 범위 중복
```
Error: IP address range is already allocated
```

**해결**:
```bash
# 기존 연결 삭제 (주의!)
gcloud services vpc-peerings delete \
    --network=vpc-main \
    --service=servicenetworking.googleapis.com \
    --project=jsj-game-k

# 다른 IP 범위 사용
# terraform.tfvars에서 psc_ip_range 변경
```

## Cloud NAT

### NAT IP 고갈
```bash
# NAT IP 할당 확인
gcloud compute routers nats describe NAT_NAME \
    --router=ROUTER_NAME \
    --region=asia-northeast3 \
    --project=jsj-game-k
```

### NAT 로그 확인
```bash
# Cloud Logging에서 NAT 로그 확인
gcloud logging read \
    "resource.type=nat_gateway" \
    --project=jsj-game-k \
    --limit=50
```

## 연결 테스트

### VM 간 연결 확인
```bash
# SSH 접속
gcloud compute ssh VM_NAME \
    --project=jsj-game-k \
    --zone=asia-northeast3-a

# 내부 통신 테스트
ping INTERNAL_IP
curl http://INTERNAL_IP

# 외부 통신 테스트 (NAT 경유)
curl https://www.google.com
```

### Cloud SQL 연결 확인
```bash
# Private IP 확인
gcloud sql instances describe INSTANCE_NAME \
    --project=jsj-game-k

# VM에서 MySQL 연결
mysql -h PRIVATE_IP -u USER -p
```

## 디버깅

### VPC Flow Logs 활성화
```hcl
# terraform.tfvars
enable_flow_logs = true
```

### Cloud Logging 확인
```bash
# VPC Flow Logs
gcloud logging read \
    "resource.type=gce_subnetwork" \
    --project=jsj-game-k \
    --limit=50

# 방화벽 로그
gcloud logging read \
    "logName=projects/jsj-game-k/logs/compute.googleapis.com%2Ffirewall" \
    --limit=50
```

## 참고

상세한 내용은 [일반적인 오류](./common-errors.md)의 네트워크 섹션을 참조하세요.

---

**관련 문서**:
- [일반적인 오류](./common-errors.md)
- [네트워크 아키텍처](../architecture/network-design.md)
- [network-dedicated-vpc 모듈](../../modules/network-dedicated-vpc/README.md)
