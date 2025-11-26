# 공통 네이밍 입력 (모든 레이어에서 공유)
# 주의: organization은 리소스 네이밍 접두어로 사용되므로 소문자/숫자/하이픈 권장
# 도메인이 있다면 슬러그 형태로: 예) mycompany.com → mycompany
project_id     = "gcp-gcby"
project_name   = "gcby"
environment    = "live"
organization   = "delabs"  # 조직명 또는 도메인 슬러그
region_primary = "us-west1"         # Oregon (오레곤)
region_backup  = "us-west2"         # Los Angeles (백업/DR)

# 선택 입력 (필요 시 주석 해제해 사용)
# default_zone_suffix = "a"   # naming.default_zone 계산 시 접미사
base_labels = {              # naming.common_labels에 병합되는 기본 라벨
  managed-by  = "terraform"
  project     = "gcby"
  team        = "system-team"
}
# extra_tags = ["prod", "gcby"]  # 공통 태그
