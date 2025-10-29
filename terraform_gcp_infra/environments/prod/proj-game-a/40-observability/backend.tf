terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "proj-game-a/40-observability"
  }
}
