terraform {
  backend "gcs" {
    bucket = "proj-game-a-terraform-state-prod"
    prefix = "15-storage"
  }
}