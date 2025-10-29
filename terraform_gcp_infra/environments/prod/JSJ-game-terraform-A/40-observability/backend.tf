terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "JSJ-game-terraform-A/40-observability"
  }
}
