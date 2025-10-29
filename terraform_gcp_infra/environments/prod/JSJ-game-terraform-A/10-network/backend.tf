terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "JSJ-game-terraform-A/10-network"
  }
}
