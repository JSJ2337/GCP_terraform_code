terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "jsj-game-c/20-storage"
  }
}