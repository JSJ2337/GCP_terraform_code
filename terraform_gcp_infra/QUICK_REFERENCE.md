# 빠른 참조 가이드

## 🚀 다음 세션 시작 시

```bash
# 1. WORK_HISTORY.md 읽기
cat WORK_HISTORY.md

# 2. 코드 포맷팅 및 검증 (완료됨)
terraform fmt -recursive

# 3. 각 레이어 검증 (완료됨)
# 모든 모듈이 validate 통과

# 4. Plan 확인 (실제 프로젝트가 있다면)
cd environments/prod/proj-game-a/00-project
terraform plan
```

## 📝 변경된 파일 요약

### 세션 1: 초기 베스트 프랙티스 적용 (11개 수정, 9개 신규)
- 모듈 7개: provider 블록 제거
- 15-storage 3개: gcs-root 사용으로 리팩토링
- locals.tf: 공통 naming
- *.tfvars.example: 설정 예제
- README.md, CHANGELOG.md, .gitignore

### 세션 2: 오류 수정 및 문서화 (3개 수정, 5개 신규)
- **오류 수정 (3개)**:
  - project-base: `google_billing_project` → `google_project`에 통합
  - network-dedicated-vpc: 중복 outputs.tf 제거
  - observability: 중복 outputs.tf 제거
- **Locals 적용 (4개)**:
  - 00-project: common_labels 적용
  - 10-network: naming convention 적용
  - 40-workloads: VM naming convention 적용
  - (15-storage는 이미 적용됨)
- **README 작성 (5개)**:
  - project-base/README.md
  - network-dedicated-vpc/README.md
  - iam/README.md
  - observability/README.md
  - gce-vmset/README.md

## ⚠️ 주의: State 마이그레이션 필요

기존 인프라가 있다면:

```bash
# 15-storage 리팩토링
terraform state mv 'module.game_assets_bucket' 'module.game_storage.module.gcs_buckets["assets"]'
terraform state mv 'module.game_logs_bucket' 'module.game_storage.module.gcs_buckets["logs"]'
terraform state mv 'module.game_backups_bucket' 'module.game_storage.module.gcs_buckets["backups"]'

# IAM 변경 시 (binding → member)
# WORK_HISTORY.md의 트러블슈팅 섹션 참조
```

## 🎯 핵심 변경 내용

### 완료됨 ✅
1. ✅ Provider 블록 제거 → 모듈 재사용성 ↑
2. ✅ IAM binding → member → 충돌 방지
3. ✅ 15-storage gcs-root 사용 → 코드 간소화
4. ✅ locals.tf 추가 → naming 일관성
5. ✅ 모듈 오류 수정 (project-base, network-dedicated-vpc, observability)
6. ✅ 코드 포맷팅 (terraform fmt)
7. ✅ 모든 모듈 검증 완료
8. ✅ 레이어에 locals 적용 (00-project, 10-network, 40-workloads)
9. ✅ 모듈 README 문서 작성 (5개)

## 📂 중요 파일

| 파일 | 용도 |
|------|------|
| WORK_HISTORY.md | 전체 작업 내역 상세 |
| CHANGELOG.md | 변경 이력 + 마이그레이션 가이드 |
| README.md | 프로젝트 전체 가이드 |
| locals.tf | 공통 naming/labeling |

## 🔧 자주 사용하는 명령어

```bash
# 포맷팅
terraform fmt -recursive

# 검증
terraform validate

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# State 확인
terraform state list

# Output 확인
terraform output -json | jq
```

## 📞 문제 해결

- **Plan에서 리소스 재생성 감지**: WORK_HISTORY.md "증상 1" 참조
- **Bucket 재생성 시도**: WORK_HISTORY.md "증상 2" 참조
- **Provider 오류**: WORK_HISTORY.md "증상 3" 참조

## ⏭️ 다음 작업 (우선순위)

### 즉시 작업 가능
1. [ ] tfsec 보안 스캔
2. [ ] 실제 프로젝트에 배포 (terraform plan/apply)
3. [ ] State 마이그레이션 (기존 인프라가 있다면)

### 향후 개선 사항
4. [ ] Dev/Staging 환경 추가
5. [ ] CI/CD 파이프라인 구축 (GitHub Actions)
6. [ ] Pre-commit hooks 설정
7. [ ] Cost estimation (infracost)
8. [ ] 20-security, 30-observability 레이어 검증

---

**상세 내용**: WORK_HISTORY.md 참조
