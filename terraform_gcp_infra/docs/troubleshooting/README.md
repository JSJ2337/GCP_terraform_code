# 🔧 Troubleshooting

문제 발생 시 빠르게 해결하기 위한 가이드입니다.

## 📚 문서 목록

### [일반적인 오류](./common-errors.md)

#### 15가지 자주 발생하는 오류 + 해결법

#### State 관련 (3개)

- "storage: bucket doesn't exist"
- State Lock 걸림
- "backend configuration changed"

#### 권한 관련 (2개)

- "Permission denied"
- Billing Account 권한 오류

#### API 관련 (2개)

- "API not enabled"
- Service Networking API 타이밍

#### 리소스 관련 (2개)

- "resource not found"
- "already exists"

#### Terragrunt 관련 (3개)

- "Unreadable module directory"
- "Missing required GCS config"
- WSL setsockopt 오류

#### 네트워크 관련 (2개)

- Private Service Connect 실패
- 방화벽 규칙 충돌

#### 기타 (1개)

- 변수 타입 불일치

### [State 문제](./state-issues.md)

- State Lock 문제
- State 손상 및 복구
- State 이동
- Bootstrap State 관리

### [네트워크 문제](./network-issues.md)

- VPC 생성 실패
- 서브넷 중복
- 방화벽 규칙 충돌
- Private Service Connect
- Cloud NAT
- 연결 테스트

## 빠른 검색

### 오류 메시지로 검색

1. [일반적인 오류](./common-errors.md)에서 Ctrl+F
2. 정확한 오류 메시지 복사/붙여넣기

### 카테고리별 검색

- **State 관련**: [State 문제](./state-issues.md)
- **네트워크 관련**: [네트워크 문제](./network-issues.md)
- **기타**: [일반적인 오류](./common-errors.md)

## 디버깅 팁

### 상세 로그 활성화

```bash
export TF_LOG=DEBUG
export TERRAGRUNT_LOG_LEVEL=debug
terragrunt plan
```

### State 검사

```bash
terragrunt state list
terragrunt state show <resource>
```

### 캐시 정리

```bash
find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;
find . -type d -name ".terraform" -prune -exec rm -rf {} \;
```

## 긴급 복구

### State 복원

```bash
# Versioning된 이전 버전 복원
gsutil ls -la gs://jsj-terraform-state-prod/jsj-game-k/00-project/
gsutil cp gs://.../default.tfstate#VERSION gs://.../default.tfstate
```

### Lock 해제

```bash
terragrunt force-unlock <LOCK_ID>
```

## 도움 요청

1. **문서 검색**: 이 포털에서 키워드 검색
2. **로그 확인**: 상세 로그로 원인 파악
3. **GitHub Issues**: 새로운 문제 보고

---

[← 문서 포털로 돌아가기](../README.md)
