#prod terraform backend
terraform {
  backend "prod" {
    bucket = "sjay3-terraform-prod"
    prefix = "reddit-prod"
  }
}
