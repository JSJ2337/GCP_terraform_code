terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "jsj-game-d/10-network"
  }
}
