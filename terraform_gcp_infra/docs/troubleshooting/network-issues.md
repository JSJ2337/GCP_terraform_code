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

#### 1. PSC Endpoint 상태 확인

**중요**: Management VPC에서 Redis Cluster로 접근하려면 **66-psc-endpoints 레이어가 배포**되어 있어야 합니다.

```bash
# PSC Endpoint IP 주소 확인
gcloud compute addresses list \
    --project=delabs-gcp-mgmt \
    --filter="name~gcby-live-redis" \
    --format="table(name,address,status)"

# 예상 출력:
# NAME                   ADDRESS        STATUS
# gcby-live-redis-0-psc  10.250.20.101  IN_USE
# gcby-live-redis-1-psc  10.250.20.102  IN_USE
```

**없는 경우**:

```bash
cd environments/LIVE/gcp-gcby/66-psc-endpoints
terragrunt apply
```

#### 2. PSC Forwarding Rule 확인

```bash
# PSC 연결 상태 확인
gcloud compute forwarding-rules list \
    --project=delabs-gcp-mgmt \
    --filter="name~gcby-live-redis" \
    --format="table(name,IPAddress,pscConnectionStatus)"

# 예상 출력:
# NAME                      IP_ADDRESS     PSC_CONNECTION_STATUS
# gcby-live-redis-0-psc-fr  10.250.20.101  ACCEPTED
```

**상태가 ACCEPTED가 아닌 경우**: 66-psc-endpoints 재배포 필요

#### 3. DNS 확인

```bash
# Bastion에서 DNS 조회
gcloud compute ssh delabs-bastion \
    --project=delabs-gcp-mgmt \
    --zone=asia-northeast3-a \
    --command="dig +short gcby-live-redis.delabsgames.internal"

# 예상: PSC Endpoint IP 반환 (예: 10.250.20.101)
```

**잘못된 IP가 반환되는 경우**: 12-dns 레이어 확인 필요

#### 4. Redis TLS 암호화 확인

GCP Memorystore Redis Cluster는 **TLS 암호화가 필수**입니다.

```bash
# Redis Cluster TLS 설정 확인
gcloud redis clusters describe gcby-live-redis \
    --region=us-west1 \
    --project=gcp-gcby \
    --format="value(transitEncryptionMode)"

# 예상 출력: TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION
```

**redis-cli 접속 시 `--tls --insecure` 옵션 필수**:

```bash
# TLS 없이 접속 (실패)
redis-cli -h gcby-live-redis.delabsgames.internal -p 6379 PING
# Error: Connection reset by peer

# TLS와 함께 접속 (성공)
redis-cli -h gcby-live-redis.delabsgames.internal -p 6379 --tls --insecure PING
# PONG
```

#### 5. ssh_vm.sh 스크립트 사용

`ssh_vm.sh`는 자동으로 TLS 옵션을 추가하여 Redis에 접속합니다.

```bash
# Bastion 접속
gcloud compute ssh delabs-bastion \
    --project=delabs-gcp-mgmt \
    --zone=asia-northeast3-a

# delabs-adm 계정으로 전환
sudo su - delabs-adm

# 스크립트 실행
./ssh_vm.sh

# Redis 선택 → redis-cli 자동 실행 (TLS 자동 적용)
```

**스크립트 특징**:

- Cloud DNS API로 자동 서버 탐색
- Database (PSC Endpoint)는 목록에서 자동 제외
- Redis는 자동으로 `--tls --insecure` 옵션 추가
- redis-cli 경로 자동 감지 (PATH, /usr/local/bin, ~/redis-7.2.6/src)

#### 6. 네트워크 경로 확인

```bash
# Bastion에서 PSC Endpoint 포트 테스트
gcloud compute ssh delabs-bastion \
    --project=delabs-gcp-mgmt \
    --zone=asia-northeast3-a \
    --command="timeout 3 bash -c '</dev/tcp/10.250.20.101/6379' && echo 'Port OPEN' || echo 'Port CLOSED'"

# 예상: Port OPEN
```

**Port CLOSED인 경우**: Management VPC 내부 방화벽 확인 (`default-allow-internal`)

### Redis CLI 명령어

```bash
# 직접 접속 (TLS 필수)
redis-cli -h gcby-live-redis.delabsgames.internal -p 6379 --tls --insecure

# 주요 명령어
PING                    # 연결 테스트 → PONG
INFO server             # 서버 정보 (버전, 모드 등)
INFO memory             # 메모리 사용량
DBSIZE                  # 전체 키 개수
CLUSTER NODES           # 클러스터 노드 정보 (Cluster 모드)
GET key_name            # 값 조회
SET key_name value      # 값 설정
DEL key_name            # 키 삭제
KEYS *                  # 모든 키 조회 (⚠️ 운영 환경에서 사용 금지!)
```

### 아키텍처 이해

**Management VPC에서 Redis Cluster 접근 경로**:

```text
Bastion (10.250.10.6, asia-northeast3)
  ↓ [Management VPC 내부 통신]
PSC Endpoint (10.250.20.101, us-west1)
  ↓ [Private Service Connect]
Redis Cluster (10.10.12.x, gcp-gcby VPC, us-west1)
```

**중요**:

- **10.10.x.x**: 각 프로젝트 내부 통신용 (gcp-gcby, gcp-web3 내부)
- **10.250.20.x**: Management VPC에서 외부 프로젝트 접근용 PSC Endpoint IP
- **VPC Peering 불필요**: PSC를 통해 프로젝트 간 통신

---

**관련 문서**:

- [일반적인 오류](./common-errors.md)
- [네트워크 아키텍처](../architecture/network-design.md)
- [network-dedicated-vpc 모듈](../modules/network-dedicated-vpc.md)
- [Memorystore Redis 모듈](../modules/memorystore-redis.md)
