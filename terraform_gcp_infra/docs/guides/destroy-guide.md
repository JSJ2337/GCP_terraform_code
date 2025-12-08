# Terraform Destroy Guide

이 문서는 GCP 환경과 템플릿을 안전하게 삭제하는 방법을 정리합니다.

## 1. Destroy 실행 방법

### 옵션 1: 전체 스택 일괄 Destroy (권장)

**환경변수를 설정하여 `run --all -- destroy` 사용** (Terragrunt 0.93+):

```bash
cd environments/LIVE/gcp-gcby

# 환경변수 설정 후 실행
export TG_NON_INTERACTIVE=true
SKIP_WORKLOADS_DEPENDENCY=true terragrunt run --all -- destroy
```

**장점**:
- 자동으로 역순 실행 (70 → 65 → ... → 00)
- dependency 에러 없음
- 빠르고 안전

### 옵션 2: 개별 레이어 Destroy

권장 순서 (역 dependency):

1. `70-loadbalancers/*`
2. `65-cache`
3. `60-database`
4. `50-workloads`
5. `40-observability`
6. `30-security`
7. `20-storage`
8. `10-network`
9. `00-project`

```bash
cd 70-loadbalancers/lobby
terragrunt destroy

cd ../web
terragrunt destroy

# 이후 순서대로...
```

## 2. Cloud SQL 삭제 보호 해제

Cloud SQL(MySQL) 인스턴스는 `deletion_protection`이 true이면 destroy가 실패합니다.

1. `environments/LIVE/<env>/60-database/terraform.tfvars`에서
   `deletion_protection = false`인지 확인
2. 이미 true로 적용된 상태라면 `terragrunt apply`를 한 번 실행해 설정을 false로 갱신
3. 이후 `terragrunt destroy` 실행

## 3. Service Networking 연결 삭제

**이미 해결됨** (2025-11-18 적용):

`modules/network-dedicated-vpc`에 `deletion_policy = "ABANDON"` 설정되어 있어 자동으로 처리됩니다.

- Terraform destroy 시: State에서만 제거, GCP에서는 유지
- VPC 삭제 시: Service Networking Connection도 자동 정리
- **수동 삭제 불필요**

만약 이전 버전을 사용 중이라면:
```bash
cd 10-network
terragrunt state rm 'module.network.google_service_networking_connection.private_vpc_connection[0]'
```

## 4. GCS Lien 제거

프로젝트에 GCS가 자동으로 거는 lien이 있으면 `00-project` destroy 시 400 오류가 납니다.

1. GCP 콘솔 → **IAM 및 관리자 → 리소스 관리자 → 프로젝트 선택 → LIENS 탭** 에서 lien 확인
2. 또는 CLI 사용:

   ```bash
   gcloud alpha resource-manager liens list --project=<PROJECT_ID>
   gcloud alpha resource-manager liens delete <LIEN_NAME>
   ```

3. lien 삭제 후 `terragrunt destroy` 재시도

## 5. 잔여 리소스 확인

- GCS 버킷, Cloud Logging sink, IAM custom role 등 Terraform 외부에서 생성된 리소스가 남아 있다면
  프로젝트 삭제가 지연될 수 있습니다.
- `gcloud projects delete <PROJECT_ID>` 실행 후 “삭제 예약” 상태가 지속되면 콘솔의
  **프로젝트 삭제 문제 해결** 문서를 참고합니다.

## 6. 수동 단계 요약

| 상황 | 조치 |
|------|------|
| Cloud SQL 삭제 보호 에러 | tfvars에서 false 설정 → `terragrunt apply` → destroy |
| Service Networking 삭제 실패 | 데이터베이스/캐시 레이어 먼저 destroy → 필요 시 VPC 피어링 수동 삭제 |
| lien 오류 | 콘솔 또는 `gcloud alpha resource-manager liens delete`로 제거 |

Destroy 작업 전에 위 항목을 미리 확인하면 대부분의 오류를 예방할 수 있습니다.
