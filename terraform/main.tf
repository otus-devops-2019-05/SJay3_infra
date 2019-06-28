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

resource "google_compute_instance" "app" {
  name = "reddit-app"
  machine_type = "g1-small"
  zone = "europe-west1-b"
  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "reddit-base"
    }
  }
  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"
    # использовать ephemeral IP для доступа из Интернет
    access_config {}
  }
}
