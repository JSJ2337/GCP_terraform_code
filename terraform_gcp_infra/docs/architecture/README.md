# 🏗️ Architecture

시스템 구조와 설계 원칙을 이해하기 위한 문서입니다.

## 📖 문서 목록

### [전체 구조](./overview.md)

- 3-Tier 아키텍처 (Bootstrap, Module, Environment)
- 9개 레이어 설명
- 모듈 설계 원칙
- 보안 및 확장성 전략

### [State 관리](./state-management.md)

- 중앙 집중식 State 전략
- GCS 버킷 구조
- Terragrunt 자동화
- 백업 및 복구

### [네트워크 설계](./network-design.md)

- DMZ/Private/DB 3-Tier 서브넷
- Private Service Connect
- Cloud NAT 구성
- 방화벽 규칙

### [다이어그램 모음](./diagrams.md)

- Mermaid 다이어그램 10개
- 시각적 아키텍처 설명
- 배포 순서 및 의존성

## 주요 개념

### 3-Tier 구조

```text
Bootstrap (관리)
    ↓
Modules (재사용)
    ↓
Environments (배포)
```

### 레이어 순서

```text
00-project → 10-network → 20-storage → 30-security
→ 40-observability → 50-workloads → 60-database
→ 65-cache → 70-loadbalancer
```

### 네트워크 흐름

```text
Internet → LB → DMZ → Private → DB
```

## 참고 자료

- [모듈 문서](../modules/)
- [배포 가이드](../getting-started/first-deployment.md)
- [트러블슈팅](../troubleshooting/)

---

[← 문서 포털로 돌아가기](../README.md)
