terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod" # ← 실제 버킷명으로 교체
    prefix = "jsj-game-d/60-database"
  }
}
