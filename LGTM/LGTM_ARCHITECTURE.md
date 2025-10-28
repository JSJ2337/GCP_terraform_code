# LGTM 스택 아키텍처 요약

이 문서는 현재 프로젝트의 관측 가능성(Observability) 스택인 LGTM (Loki, Grafana, Tempo, Mimir)의 아키텍처를 요약합니다.

## 1. 전체 아키텍처

이 스택은 모든 원격 측정 데이터(메트릭, 로그, 트레이스)를 **Grafana Alloy**를 사용하여 수집하고, **Mimir, Loki, Tempo** 백엔드에 저장한 뒤, **Grafana**를 통해 통합적으로 시각화하고 분석하는 구조입니다.

모든 백엔드 서비스는 Docker 컨테이너로 실행되며 `mimir-net`이라는 공통 네트워크를 통해 통신합니다.

### 데이터 흐름

```
                               +---------------------+
                               |      Grafana        |
                               | (Visualization)     |
                               +---------------------+
                                     ^   ^   ^
                                     |   |   | Queries
                                     |   |   |
      +------------------------------+   |   +--------------------------------+
      |                                  |                                    |
      v                                  v                                    v
+-----+-------------+         +----------+----------+         +----------------+----+
|   Mimir           |         |   Loki              |         |   Tempo             |
| (Metrics Backend) |         | (Logs Backend)      |         | (Traces Backend)    |
+-------------------+         +---------------------+         +---------------------+
      ^      ^                        ^      ^                        ^
      |      | Metrics                |      | Logs                   | Traces
      |      |                        |      |                        |
      |      +------------------------+      |                        |
      |                                      |                        |
+-----+--------------------------------------+------------------------+-----+
|                            Grafana Alloy (Data Collector)                  |
|                                                                            |
|  +-------------------------+     +------------------------------------+   |
|  | Alloy as Agent          |     | Alloy as Collector                 |   |
|  | (on EC2 Instances)      |     | (Docker Container)                 |   |
|  | - System Metrics (CPU, Mem) |     | - AWS CloudWatch Metrics (RDS, ELB)|   |
|  | - System Logs (journald)  |     | - AWS CloudWatch Logs (RDS)      |   |
|  | - App Traces (OTLP)     |     |                                    |   |
|  +-------------------------+     +------------------------------------+   |
+----------------------------------------------------------------------------+

```

## 2. 컴포넌트별 역할 및 설정

### 2.1. 데이터 수집: Grafana Alloy

모든 데이터 수집은 Grafana Alloy가 담당하며, 두 가지 모드로 운영됩니다.

*   **Agent 모드 (`ftt-alloy-agent` 스크립트):**
    *   **역할:** 개별 EC2 인스턴스(Linux/Windows)에 직접 설치되어 시스템 레벨의 데이터를 수집합니다.
    *   **수집 대상:**
        *   **메트릭:** 시스템 메트릭 (CPU, 메모리, 디스크, 네트워크 등)
        *   **로그:** 시스템 로그 (`journald` 또는 Windows Event Log)
        *   **트레이스:** OTLP 엔드포인트를 통해 애플리케이션 트레이스 수집
    *   **전송 대상:** 수집한 메트릭은 Mimir, 로그는 Loki, 트레이스는 Tempo로 전송합니다.
    *   **테넌트 ID:** `aws-rag-ec2`

*   **Collector 모드 (`ftt-alloy` Docker 컨테이너):**
    *   **역할:** 별도의 Docker 컨테이너로 실행되며, AWS와 같은 클라우드 서비스의 API를 통해 데이터를 수집합니다.
    *   **수집 대상:**
        *   **메트릭:** AWS CloudWatch Metrics (RDS, ALB, NLB, ElastiCache 등)
        *   **로그:** AWS CloudWatch Logs (RDS 등)
    *   **전송 대상:** 수집한 메트릭은 Mimir, 로그는 Loki로 전송합니다.
    *   **테넌트 ID:** `aws-rag-cloudwatch` (메트릭), `aws-rag-rds` (로그)

### 2.2. 백엔드 서비스

*   **Mimir (`ftt-mimir`): 메트릭 저장소**
    *   **역할:** 모든 메트릭 데이터의 저장, 압축, 쿼리를 담당합니다.
    *   **스토리지:** S3 (`rag-mimir-pos-s3` 버킷)에 1년간 장기 보관하며, 로컬 디스크와 Memcached를 캐시로 사용해 성능을 최적화합니다.
    *   **모드:** 모놀리식(`-target=all`) 모드로 단일 컨테이너에서 실행됩니다.
    *   **테넌트:** `X-Scope-OrgID` 헤더를 통해 멀티테넌시를 지원합니다.

*   **Loki (`ftt-loki`): 로그 저장소**
    *   **역할:** 모든 로그 데이터의 저장, 인덱싱, 쿼리를 담당합니다.
    *   **스토리지:** 로그 내용은 S3(`rag-mimir-pos-s3` 버킷)에, 인덱스는 로컬 디스크(TSDB)에 저장하는 "boltdb-shipper"와 유사한 모델을 사용합니다.
    *   **테넌트:** `X-Scope-OrgID` 헤더를 통해 멀티테넌시를 지원합니다.

*   **Tempo:** 트레이스 저장소 (설정 파일에만 존재)
    *   Alloy 설정에 Tempo로 트레이스를 보내는 부분이 있으나, `docker-compose` 파일이 없어 현재 실행 중인 컴포넌트는 아닌 것으로 보입니다. 추후 추가될 가능성이 있습니다.

### 2.3. 시각화: Grafana (`ftt-grafana`)

*   **역할:** 전체 스택의 데이터를 조회하고 시각화하는 통합 UI입니다.
*   **데이터 소스:** Mimir와 Loki가 데이터 소스로 프로비저닝되어 있어야 합니다.
*   **기능:** 사용자는 Grafana 대시보드를 통해 Mimir의 메트릭과 Loki의 로그를 연관 분석할 수 있습니다. 멀티테넌트 헤더(`GF_DATASOURCE_TENANTS`) 설정을 통해 테넌트별 데이터 조회를 지원합니다.

## 3. 레거시 컴포넌트

*   **ADOT + Node Exporter (`ADOT+node_exporter` 폴더):**
    *   더 이상 사용되지 않으며, Grafana Alloy Agent로 완전히 대체되었습니다.
