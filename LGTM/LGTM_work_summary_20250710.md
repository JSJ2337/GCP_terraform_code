# LGTM 프로젝트 작업 요약 (2025년 7월 10일)

## 1. Loki 설정 파일 (`loki-config.yaml`) 수정 내역

### 1.1. `log_config` 섹션 추가 및 제거
*   **초기 시도:** 로그를 메트릭화하기 위해 `loki-config.yaml`에 `log_config` 섹션과 `metric_extraction_rules` (에러, 워닝, 인포, 전체 로그 라인 카운트)를 추가했습니다.
*   **문제 발생:** Loki 컨테이너 실행 시 `field log_config not found` 오류가 발생했습니다.
*   **원인 파악:** Loki 3.x 버전에서는 `loki-config.yaml`을 통한 `log_config` 방식이 표준적으로 지원되지 않음을 확인했습니다. 로그로부터의 메트릭 추출은 주로 Grafana에서 LogQL 쿼리를 통해 이루어집니다.
*   **해결:** `loki-config.yaml`에서 `log_config` 섹션 전체를 제거했습니다.

### 1.2. S3 스토리지 설정 수정
*   **문제 발생:** `storage_config` 및 `ruler.storage` 섹션에서 `bucket_name`, `bucket_lookup_type` 필드를 찾을 수 없다는 오류가 발생했습니다.
*   **원인 파악:** Loki 3.x의 S3 설정 구조가 기존과 달랐습니다.
*   **해결:**
    *   `storage_config`: `object_store` 아래 `type: s3`와 `config:` 중첩 대신, `aws:` 아래에 `bucketnames`, `endpoint`, `region`을 직접 명시하도록 수정했습니다.
    *   `ruler.storage`: `type: s3` 아래 `config:` 중첩 대신, `s3:`를 중첩하고 그 아래에 `bucketnames`, `endpoint`, `region`을 직접 명시하도록 수정했습니다.
    *   `schema_config`: `object_store` 필드가 `s3` 문자열을 직접 값으로 가지도록 수정했습니다.

### 1.3. Mimir 컨테이너 주소 수정
*   **문제 발생:** `loki-config.yaml`의 `remote_write` 섹션에 Mimir 주소가 `http://mimir:8080/api/v1/push`로 설정되어 있었으나, 실제 Mimir 컨테이너 이름이 `ftt-mimir`임을 확인했습니다.
*   **해결:** `url`을 `http://ftt-mimir:8080/api/v1/push`로 수정했습니다.

## 2. Docker Compose 파일 (`ftt-loki-docker-compose.yaml`) 수정 내역

### 2.1. Loki 설정 파일 참조 경로 수정
*   **문제 발생:** `ftt-loki-docker-compose.yml_v2.yaml`이 `loki-config_v1.yaml`을 참조하도록 설정되어 있었고, 컨테이너 내부 경로도 잘못 설정되어 있었습니다.
*   **해결:**
    *   `command` 섹션에서 Loki가 컨테이너 내부의 `/etc/loki/loki-config.yaml`을 사용하도록 수정했습니다.
    *   `volumes` 섹션에서 호스트의 `./config/loki-config.yaml` 파일을 컨테이너 내부의 `/etc/loki/loki-config.yaml`로 마운트하도록 수정했습니다. (이 과정에서 `config` 디렉토리 생성 및 `loki-config_v1.yaml` 이동에 대한 논의가 있었으나, 최종적으로는 배포용 파일명 규칙에 따라 `loki-config.yaml`을 참조하도록 결정되었습니다.)

### 2.2. 파일명 버전 관리 일관성 확보
*   **문제 발생:** 배포용 파일은 파일명에 버전을 표기하지 않아야 한다는 규칙에도 불구하고 `ftt-loki-docker-compose.yml_v2.yaml` 파일명에 `_v2`가 포함되어 있었습니다.
*   **해결:** `ftt-loki-docker-compose.yml_v2.yaml` 파일의 이름을 `ftt-loki-docker-compose.yaml`으로 변경했습니다.

## 3. LGTM 아키텍처 이해 및 향후 작업 방향

*   **Grafana Alloy의 역할:** `LGTM_ARCHITECTURE.md` 문서를 통해 Grafana Alloy가 모든 원격 측정 데이터(메트릭, 로그, 트레이스)의 주요 수집 도구임을 확인했습니다. 특히 로그 수집 및 메트릭 추출은 Alloy가 담당합니다.
*   **Loki의 역할:** Loki는 로그 저장소 백엔드 역할을 수행합니다.
*   **Loki `ruler`의 역할:** Loki의 `ruler`는 Loki에 저장된 로그 데이터를 기반으로 추가적인 메트릭 기록 규칙 및 알림 규칙을 생성하는 데 사용될 수 있습니다.
*   **향후 작업:** 로그에서 메트릭을 추출하여 Mimir로 전송하는 작업은 이제 Grafana Alloy 설정 파일(`ftt-alloy` 디렉토리 내 파일)을 수정하여 진행해야 합니다.

## 4. 파일 버전 관리 원칙 재확인

*   **형상 관리용 파일:** `loki-config_v1.yaml`과 같이 **파일명에만 버전을 표기**하고, 내용에는 버전 정보를 넣지 않습니다.
*   **배포용 파일:** `loki-config.yaml`, `ftt-loki-docker-compose.yaml`과 같이 **파일명에 버전을 표기하지 않고**, 내용에도 버전 정보를 넣지 않습니다. 배포 시에는 형상 관리용 파일의 최신 내용을 배포용 파일로 업데이트하여 사용합니다.
