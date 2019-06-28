terraform {
  # версия terraform
  required_version = "0.11.11"
}

provider "google" {
  # Версия провайдера
  version = "2.0.0"

  # id проекта
  project = "infra-244211"

  region = "europe-west-1"
}
