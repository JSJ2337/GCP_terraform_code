terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "jsj-game-d/30-security"
  }
}
