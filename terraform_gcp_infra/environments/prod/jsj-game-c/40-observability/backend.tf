terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "jsj-game-c/40-observability"
  }
}
