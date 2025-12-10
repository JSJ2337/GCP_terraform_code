# 네트워크 문제 해결

네트워크 관련 문제 해결 가이드입니다.

## VPC 문제

### VPC 생성 실패

```bash
# 기존 VPC 확인
gcloud compute networks list --project=gcp-gcby

# 충돌 시 Import
terragrunt import google_compute_network.main \
    projects/gcp-gcby/global/networks/vpc-name
```

### 서브넷 중복

```bash
# 기존 서브넷 확인
gcloud compute networks subnets list \
    --network=vpc-main \
    --project=gcp-gcby

# CIDR 범위 충돌 확인
```

## 방화벽 규칙

### 규칙 충돌

```bash
# 기존 규칙 확인
gcloud compute firewall-rules list --project=gcp-gcby

# 수동 생성된 규칙 삭제
gcloud compute firewall-rules delete RULE_NAME --project=gcp-gcby

# Import
terragrunt import google_compute_firewall.rule \
    projects/gcp-gcby/global/firewalls/RULE_NAME
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
    --project=gcp-gcby
```

### IP 범위 중복

```text
Error: IP address range is already allocated
```

**해결**:

```bash
# 기존 연결 삭제 (주의!)
gcloud services vpc-peerings delete \
    --network=vpc-main \
    --service=servicenetworking.googleapis.com \
    --project=gcp-gcby

# 다른 IP 범위 사용
# terraform.tfvars에서 psc_ip_range 변경
```

## Cloud NAT

### NAT IP 고갈

```bash
# NAT IP 할당 확인
gcloud compute routers nats describe NAT_NAME \
    --router=ROUTER_NAME \
    --region=us-west1 \
    --project=gcp-gcby
```

### NAT 로그 확인

```bash
# Cloud Logging에서 NAT 로그 확인
gcloud logging read \
    "resource.type=nat_gateway" \
    --project=gcp-gcby \
    --limit=50
```

## 연결 테스트

### VM 간 연결 확인

```bash
# SSH 접속
gcloud compute ssh VM_NAME \
    --project=gcp-gcby \
    --zone=us-west1-a

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
    --project=gcp-gcby

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
    --project=gcp-gcby \
    --limit=50

# 방화벽 로그
gcloud logging read \
    "logName=projects/gcp-gcby/logs/compute.googleapis.com%2Ffirewall" \
    --limit=50
```

## 참고

상세한 내용은 [일반적인 오류](./common-errors.md)의 네트워크 섹션을 참조하세요.

## Redis 접속 문제

### Bastion에서 Redis 접속 실패

**증상**: `Connection reset by peer` 또는 `Connection refused`

#### 1. 방화벽 규칙 확인

```bash
# Management VPC → Redis 방화벽 규칙 확인
gcloud compute firewall-rules describe allow-redis-from-mgmt \
    --project=gcp-gcby \
    --format="table(name,sourceRanges,allowed)"
```

**예상 출력**:

```text
NAME                   SOURCE_RANGES      ALLOWED
allow-redis-from-mgmt  10.250.10.0/24     tcp:6379
```

**없는 경우**: `gcp-gcby/10-network` Terragrunt 적용 필요

#### 2. Redis Cluster 상태 확인

```bash
# Redis Cluster 조회
gcloud redis clusters list --region=us-west1 --project=gcp-gcby

# Discovery Endpoint 확인
gcloud redis clusters describe gcby-live-redis \
    --region=us-west1 \
    --project=gcp-gcby \
    --format="value(discoveryEndpoints[0].address)"
```

#### 3. VPC Peering 확인

```bash
# Management VPC → Project VPC 피어링 확인
gcloud compute networks peerings list \
    --network=delabs-gcp-mgmt-vpc \
    --project=delabs-gcp-mgmt \
    | grep gcby
```

**예상**: `peering-mgmt-to-gcby` 상태가 `ACTIVE`

#### 4. DNS 확인

```bash
# Bastion에서 DNS 조회
gcloud compute ssh delabs-bastion \
    --project=delabs-gcp-mgmt \
    --zone=asia-northeast3-a \
    --command="dig +short gcby-live-redis.delabsgames.internal"
```

**예상**: Redis Discovery Endpoint IP 반환 (예: `10.10.12.3`)

#### 5. ssh_vm.sh 스크립트 사용

```bash
# Bastion 접속
gcloud compute ssh delabs-bastion \
    --project=delabs-gcp-mgmt \
    --zone=asia-northeast3-a

# delabs-adm 계정으로 전환
sudo su - delabs-adm

# 스크립트 실행
./ssh_vm.sh

# Redis 선택 → redis-cli 자동 실행
```

**참고**: `ssh_vm.sh`는 Cloud DNS API를 사용하여 자동으로 Redis Cluster를 감지합니다. Bastion에 `bastion-host` Service Account가 연결되어 있어야 합니다.

### Redis CLI 명령어

```bash
# 직접 접속
redis-cli -h gcby-live-redis.delabsgames.internal -p 6379

# 주요 명령어
INFO                    # 서버 정보
PING                    # 연결 테스트
KEYS *                  # 모든 키 조회 (운영 환경 주의!)
GET key_name            # 값 조회
SET key_name value      # 값 설정
DEL key_name            # 키 삭제
```

---

**관련 문서**:

- [일반적인 오류](./common-errors.md)
- [네트워크 아키텍처](../architecture/network-design.md)
- [network-dedicated-vpc 모듈](../modules/network-dedicated-vpc.md)
- [Memorystore Redis 모듈](../modules/memorystore-redis.md)
