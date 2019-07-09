#stage terraform backend
terraform {
  backend "stage" {
    bucket = "sjay3-terraform-stage"
    prefix = "reddit-stage"
  }
}
