# Example Configuration Files

이 디렉토리에는 일부 레이어 및 모듈의 예제 설정 파일들이 있습니다.

## 레이어 예제

| 파일명 | 설명 |
|--------|------|
| `layers/12-dns.tfvars.example` | Cloud DNS 레이어 설정 예제 (Public/Private Zone, DNSSEC, Forwarding 등) |

## 모듈 예제

| 파일명 | 설명 |
|--------|------|
| `modules-gcs-root.tfvars.example` | GCS Root 모듈 설정 예제 |

## 사용 방법

1. 필요한 예제 파일을 해당 레이어 디렉토리로 복사
2. 파일명을 `terraform.tfvars`로 변경
3. 프로젝트에 맞게 값 수정

```bash
# 예시: 12-dns 레이어에 예제 복사
cp docs/examples/layers/12-dns.tfvars.example environments/LIVE/my-project/12-dns/terraform.tfvars
```
