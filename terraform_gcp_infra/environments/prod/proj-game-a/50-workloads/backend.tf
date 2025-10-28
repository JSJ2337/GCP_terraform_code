terraform {
  backend "gcs" {
    bucket = "gcp-tfstate-prod"
    prefix = "proj-game-a/50-workloads"
  }
}
