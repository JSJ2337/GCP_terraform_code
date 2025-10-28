# 변경 이력

이 프로젝트의 모든 주요 변경 사항이 이 파일에 기록됩니다.

## [미배포] - 2025-10-28

### 변경 - 베스트 프랙티스 개선

#### 높은 우선순위 수정

- **모든 모듈에서 provider 블록 제거**
  - 모듈에서 더 이상 `provider` 블록을 선언하지 않음
  - 모듈에는 `required_providers`만 지정
  - Provider 구성은 루트 레벨에서만 관리
  - 모듈 재사용성 향상 및 버전 충돌 방지
  - 영향받는 모듈: gcs-root, gcs-bucket, project-base, network-dedicated-vpc, iam, observability, gce-vmset

- **IAM binding에서 member로 마이그레이션**
  - `google_storage_bucket_iam_binding`을 `google_storage_bucket_iam_member`로 변경
  - Non-authoritative 방식으로 기존 권한 덮어쓰기 방지
  - Terraform 외부에서 설정한 권한이 실수로 제거되는 위험 감소
  - 모듈: gcs-bucket

- **Notification 리소스 키 충돌 수정**
  - Notification의 for_each 키를 `topic`에서 인덱스로 변경
  - 동일한 topic에 대해 여러 notification 생성 가능
  - 모듈: gcs-bucket

#### 중간 우선순위 개선

- **15-storage를 gcs-root 모듈 사용으로 리팩토링**
  - 3개의 개별 모듈 호출을 하나의 gcs-root 사용으로 통합
  - 코드 중복 감소
  - 공통 설정 중앙화 (labels, KMS key, public access prevention)
  - 유지 관리 및 확장 용이

- **공통 naming 규칙 추가**
  - 표준화된 naming 패턴으로 `locals.tf` 생성
  - 모든 리소스에 대한 공통 label 정의
  - 일관된 리소스 prefix 설정
  - 위치: environments/prod/proj-game-a/locals.tf

- **terraform.tfvars.example 파일 생성**
  - 필수 변수에 대한 템플릿 제공
  - 유용한 주석 및 예제 포함
  - 추가 대상: 00-project, 15-storage
  - 민감한 값의 실수로 인한 커밋 방지

#### 문서화

- **포괄적인 README 파일 추가**
  - 전체 문서가 포함된 메인 프로젝트 README
  - gcs-root 및 gcs-bucket에 대한 모듈별 README
  - 사용 예제 및 베스트 프랙티스
  - Input/output 문서

- **.gitignore 생성**
  - Terraform state 파일 제외
  - *.tfvars 제외 (*.tfvars.example은 유지)
  - .terraform 디렉토리 제외
  - IDE 및 편집기 파일 포함

### 보안 개선

- Non-authoritative IAM 바인딩 강제 적용
- 공개 액세스 방지 기본값 유지
- Uniform bucket-level access 활성화 유지
- CMEK 암호화 지원 유지

### 코드 품질

- 모듈에서 provider 선언 제거
- for_each 키 고유성 개선
- 관심사 분리 개선
- 더 유지 관리하기 쉬운 코드 구조

## 마이그레이션 가이드

### 기존 배포된 인프라가 있는 경우

이전 코드로 배포된 기존 인프라가 있는 경우:

1. **Provider 블록 제거** - State 변경 불필요, 루트 구성만 업데이트

2. **IAM binding에서 member로** - 주의 깊은 마이그레이션 필요:
   ```bash
   # 현재 IAM 바인딩 확인
   terraform state list | grep iam_binding

   # member로 import 필요할 수 있음
   terraform import 'module.gcs_bucket.google_storage_bucket_iam_member.members["role-member"]' ...
   ```

3. **15-storage 리팩토링** - State 마이그레이션 필요:
   ```bash
   # 개별 모듈에서 gcs-root로 state 이동
   terraform state mv 'module.game_assets_bucket' 'module.game_storage.module.gcs_buckets["assets"]'
   terraform state mv 'module.game_logs_bucket' 'module.game_storage.module.gcs_buckets["logs"]'
   terraform state mv 'module.game_backups_bucket' 'module.game_storage.module.gcs_buckets["backups"]'
   ```

### 변경 사항 테스트

프로덕션에 적용하기 전:

```bash
# 코드 포맷팅
terraform fmt -recursive

# 검증
terraform validate

# 보안 스캔
tfsec .

# 적용하지 않고 Plan만 확인
terraform plan
```

## 적용된 베스트 프랙티스

✅ 모듈 내 provider 블록 없음
✅ Non-authoritative IAM 관리
✅ 고유한 for_each 키
✅ 중앙화된 naming 규칙
✅ 예제 tfvars 파일
✅ 포괄적인 문서화
✅ 적절한 .gitignore
✅ 보안 우선 기본값

## 향후 개선 사항

- [ ] dev 및 staging 환경 추가
- [ ] CI/CD에 tfsec 구현
- [ ] 포맷팅을 위한 pre-commit hook 추가
- [ ] 추가 모듈 README 작성
- [ ] terraform-docs 자동화 추가
- [ ] OPA/Sentinel을 사용한 policy-as-code 구현
