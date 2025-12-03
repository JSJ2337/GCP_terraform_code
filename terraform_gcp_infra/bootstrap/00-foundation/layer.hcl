# 00-foundation 레이어 설정
#
# 환경 변수:
#   - TG_BOOTSTRAP_ADMIN_EMAIL: 관리자 이메일 (IAP/OSLogin용, 기본값: itinfra@delabsgames.gg)

locals {
  # 관리자 이메일 (환경 변수에서 가져오거나 기본값 사용)
  admin_email = get_env("TG_BOOTSTRAP_ADMIN_EMAIL", "itinfra@delabsgames.gg")

  # 폴더 구조 관리 (게임/리전/환경)
  manage_folders = true

  # 게임별 리전 매핑 - 새 게임 추가 시 여기만 수정!
  product_regions = {
    "gcp-gcby" = ["us-west1"]
    # 새 게임 추가 예시:
    # "new-game" = ["asia-northeast3", "us-central1"]
  }

  # 조직 레벨 IAM 관리 여부
  manage_org_iam = false

  # 청구 계정 IAM 바인딩 (조직 관리자가 수동 설정 필요)
  enable_billing_account_binding = false

  # Folder ID (조직 최상위에 생성시 null)
  folder_id = null

  # IAP 터널 접근 권한 멤버 (동적 생성)
  iap_tunnel_members = ["user:${local.admin_email}"]

  # OS Login 관리자 (sudo 권한, 동적 생성)
  os_login_admins = ["user:${local.admin_email}"]

  # OS Login 일반 사용자
  os_login_users = []
}
