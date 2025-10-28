terraform {
  backend "gcs" {
    bucket = "gcp-tfstate-prod"
    prefix = "proj-game-a/30-observability"
  }
}
