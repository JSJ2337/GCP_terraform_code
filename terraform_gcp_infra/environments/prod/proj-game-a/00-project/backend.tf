terraform {
  backend "gcs" {
    bucket = "gcp-tfstate-prod" # ← 실제 버킷명으로 교체
    prefix = "proj-game-a/00-project"
  }
}
