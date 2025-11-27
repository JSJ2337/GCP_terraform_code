# 공통 네이밍 입력 (모든 레이어에서 공유)
# 주의: organization은 리소스 네이밍 접두어로 사용되므로 소문자/숫자/하이픈 권장
# 도메인이 있다면 슬러그 형태로: 예) mycompany.com → mycompany
project_id     = "my-project-live"
project_name   = "my-project"
environment    = "live"      # live (운영), qa-dev (개발/QA)
organization   = "myorg"     # 조직명 또는 도메인 슬러그
region_primary = "asia-northeast3"
region_backup  = "asia-northeast1"

# Bootstrap 폴더 설정 (environment_folder_ids 키 조회용)
# 형식: product/region/env → "my-game/us-west1/LIVE"
# ⚠️ bootstrap/00-foundation/layer.hcl의 product_regions에 등록 필요!
folder_product = "my-game"
folder_region  = "us-west1"
folder_env     = "LIVE"

# 선택 입력 (필요 시 주석 해제해 사용)
# default_zone_suffix = "a"   # naming.default_zone 계산 시 접미사
# base_labels = {              # naming.common_labels에 병합되는 기본 라벨
#   managed-by  = "terraform"
#   cost-center = "gaming"
# }
# extra_tags = ["live", "game"]  # 공통 태그
