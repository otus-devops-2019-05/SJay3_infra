#prod terraform backend
terraform {
  backend "gcs" {
    bucket = "sjay3-terraform-prod"
    prefix = "reddit-prod"
  }
}
