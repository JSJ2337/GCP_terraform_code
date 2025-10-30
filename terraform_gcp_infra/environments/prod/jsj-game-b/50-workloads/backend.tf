terraform {
  backend "gcs" {
    bucket = "delabs-terraform-state-prod"
    prefix = "proj-default-templet/50-workloads"
  }
}
