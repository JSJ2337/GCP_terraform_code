# 00-foundation 레이어 설정

locals {
  # 폴더 구조 관리 (게임/리전/환경)
  manage_folders = true

  # 조직 레벨 IAM 관리 여부
  manage_org_iam = false

  # 청구 계정 IAM 바인딩 (조직 관리자가 수동 설정 필요)
  enable_billing_account_binding = false

  # Folder ID (조직 최상위에 생성시 null)
  folder_id = null

  # IAP 터널 접근 권한 멤버
  iap_tunnel_members = ["user:itinfra@delabsgames.gg"]

  # OS Login 관리자 (sudo 권한)
  os_login_admins = ["user:itinfra@delabsgames.gg"]

  # OS Login 일반 사용자
  os_login_users = []
}
