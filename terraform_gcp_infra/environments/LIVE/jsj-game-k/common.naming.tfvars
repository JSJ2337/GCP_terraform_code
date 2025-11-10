# 공통 네이밍 입력 (모든 레이어에서 공유)
# 주의: organization은 리소스 네이밍 접두어로 사용되므로 소문자/숫자/하이픈 권장
# 도메인이 있다면 슬러그 형태로: 예) jsj-dev.com → jsj-dev
project_id     = "jsj-game-k"
project_name   = "game-k"
environment    = "prod"
organization   = "jsj-dev"  # 실제 도메인: jsj-dev.com
region_primary = "asia-northeast3"
region_backup  = "asia-northeast1"

# 선택 입력 (필요 시 주석 해제해 사용)
# default_zone_suffix = "a"   # naming.default_zone 계산 시 접미사
# base_labels = {              # naming.common_labels에 병합되는 기본 라벨
#   managed-by  = "terraform"
#   cost-center = "gaming"
# }
# extra_tags = ["prod", "game"]  # 공통 태그
