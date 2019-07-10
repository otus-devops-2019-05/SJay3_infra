#stage terraform backend
terraform {
  backend "gcs" {
    bucket = "sjay3-terraform-stage"
    prefix = "reddit-stage"
  }
}
