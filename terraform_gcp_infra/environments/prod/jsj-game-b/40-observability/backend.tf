terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "proj-default-templet/40-observability"
  }
}
