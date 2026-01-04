# Terraform Modules 문서

재사용 가능한 Terraform 모듈들의 상세 문서입니다.

## 모듈 목록

### 기본 인프라

| 모듈 | 설명 | 문서 |
|------|------|------|
| **project-base** | GCP 프로젝트 생성 및 API 활성화 | [project-base.md](./project-base.md) |
| **naming** | 중앙 집중식 네이밍 규칙 관리 | [naming.md](./naming.md) |
| **iam** | IAM 바인딩 및 서비스 계정 관리 | [iam.md](./iam.md) |

### 네트워크

| 모듈 | 설명 | 문서 |
|------|------|------|
| **network-dedicated-vpc** | VPC, Subnet, Firewall 구성 | [network-dedicated-vpc.md](./network-dedicated-vpc.md) |
| **cloud-dns** | Cloud DNS Zone 및 레코드 관리 | [cloud-dns.md](./cloud-dns.md) |
| **load-balancer** | HTTP(S) 및 TCP Load Balancer | [load-balancer.md](./load-balancer.md) |

### 스토리지

| 모듈 | 설명 | 문서 |
|------|------|------|
| **gcs-root** | 다중 GCS 버킷 관리 (루트 모듈) | [gcs-root.md](./gcs-root.md) |
| **gcs-bucket** | 단일 GCS 버킷 상세 설정 | [gcs-bucket.md](./gcs-bucket.md) |

### 컴퓨팅

| 모듈 | 설명 | 문서 |
|------|------|------|
| **gce-vmset** | Compute Engine VM 인스턴스 관리 | [gce-vmset.md](./gce-vmset.md) |

### 데이터베이스 & 캐시

| 모듈 | 설명 | 문서 |
|------|------|------|
| **cloudsql-mysql** | Cloud SQL MySQL 인스턴스 | [cloudsql-mysql.md](./cloudsql-mysql.md) |
| **memorystore-redis** | Memorystore Redis 클러스터 | [memorystore-redis.md](./memorystore-redis.md) |

### 모니터링

| 모듈 | 설명 | 문서 |
|------|------|------|
| **observability** | Cloud Logging 및 Monitoring | [observability.md](./observability.md) |

## 레이어별 모듈 매핑

| 레이어 | 사용 모듈 |
|--------|----------|
| 00-project | project-base, naming |
| 10-network | network-dedicated-vpc, naming |
| 12-dns | cloud-dns, naming |
| 20-storage | gcs-root, gcs-bucket, naming |
| 30-security | iam, naming |
| 40-observability | observability, naming |
| 50-workloads | gce-vmset, naming |
| 60-database | cloudsql-mysql, naming |
| 65-cache | memorystore-redis, naming |
| 66-psc-endpoints | (인라인) Cross-project PSC 등록 |
| 70-loadbalancers | load-balancer, naming |

> **참고**: `66-psc-endpoints`는 별도 모듈 없이 인라인 Terraform 코드로 구현되어 있습니다. mgmt VPC에서 각 프로젝트의 Cloud SQL/Redis에 접근하기 위한 PSC Endpoint를 등록합니다.

---

[← 문서 포털로 돌아가기](../README.md)
