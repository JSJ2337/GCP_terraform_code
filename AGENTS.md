# Repository Guidelines

## 프로젝트 구조 및 모듈 구성
`terraform_gcp_infra/` 디렉터리는 실사용 Terraform 코드의 홈입니다. 공통 로직은 `modules/`에, 환경별 배포 스택은 `environments/<env>/`에 배치합니다. 새로운 패턴은 먼저 `terraform_training/`에서 실험해 검증한 뒤 본 레포에 반영합니다. AWS 자동화 스크립트는 `AWS_script/` 아래 기능별로 나뉘며 (`autoscaling/`은 셸 유틸, `lambda/`는 Python 핸들러), 관측 관련 자산은 `LGTM/`에 정리되어 있습니다. 유사한 항목 옆에 새 파일을 추가하고, 구조 변경 시에는 해당 폴더 README에 간단히 기록하세요.

## 빌드·테스트·개발 명령
- `terraform -chdir=terraform_gcp_infra/environments/dev init`: 작업하려는 환경을 준비합니다 (`dev`를 맞는 환경으로 교체).
- `terraform fmt && terraform validate`: 모든 Terraform 수정 후 실행해 포맷과 정적 검사를 통과시킵니다.
- `terraform -chdir=terraform_gcp_infra/environments/dev plan`: diff를 검토하고 의미 있는 변경이면 계획 출력물을 공유합니다.
- `bash AWS_script/autoscaling/autoscaling_script_v1.5.sh`: 최신 오토스케일링 도우미 스크립트를 실행합니다. 옵션은 `--help`로 확인합니다.
- `python3 AWS_script/lambda/aws_eventbritge_to_rds_v2.1.py`: Lambda 스크립트를 로컬에서 스모크 테스트합니다(클라이언트는 모킹 추천).

## 코딩 스타일 및 이름 규칙
Terraform은 두 칸 들여쓰기, 소문자 리소스 이름, 반복 접두사는 locals/variables로 공유합니다. 저장 전 `terraform fmt`를 필수로 돌립니다. Bash 스크립트는 `/usr/bin/env bash` shebang과 `set -euo pipefail`을 기본으로 하며 함수는 `동사_명사` 형태로 짓습니다. Python 도구는 4칸 들여쓰기와 `snake_case`를 따르고 Python 3.9 호환을 유지합니다. 포맷은 `black --line-length 100`, 린팅은 `flake8`을 사용하세요. 기능 변경 시 버전을 반영한 파일명을 씁니다(`autoscaling_script_v1.6.sh` 등).

## 테스트 가이드
Terraform 변경 시마다 `terraform validate`와 영향 환경의 `terraform plan`을 실행해 결과를 검토·공유합니다. 모듈 입력이 바뀌면 `terraform_training/`의 예제를 최신 상태로 맞춥니다. 셸 스크립트는 `shellcheck <파일>`을 통과시키고 가능하다면 dry-run 모드를 제공합니다. Python 핸들러는 I/O와 비즈니스 로직을 분리하고, 새로운 로직에는 `pytest` 또는 `python -m unittest` 기반 단위 테스트를 추가합니다.

## 커밋 및 PR 가이드라인
Git 기록은 Conventional Commit 접두사(`feat:`, `refactor:`, `chore:`)와 간결한 한글 요약을 혼용합니다. 동사를 포함한 명령형 제목과 선택적 스코프(예: `infra`)를 지켜 주세요. Terraform, 스크립트, 문서 수정은 관련된 것끼리 묶고 설명을 명확히 남깁니다. PR에는 수동 apply 절차, 관련 plan/log, 이슈 링크를 포함합니다. 프로덕션 영향 변경은 다른 인프라 엔지니어의 리뷰를 받고, 후속 작업이 있으면 본문에 정리합니다.

## 보안 및 설정 팁
민감한 시크릿이나 실제 `.tfstate` 파일은 버전에 올리지 마세요. 예제 공유가 필요하면 민감 정보는 마스킹합니다. 임시 산출물은 `tmp_plugin_dir/` 또는 로컬 워크스페이스에 보관하고, 새 임시 경로는 `.gitignore`에 추가합니다. 높은 권한이 필요한 GCP/IAM 설정을 만들면 `terraform_gcp_infra/01_ARCHITECTURE.md`에 요구 사항을 기록해 추후 작업자가 맥락을 이해하도록 돕습니다.
