#app
data "template_file" "puma_service" {
  template = "${file("${path.module}/files/puma.service")}"
  vars = {
    db_hostname = "${var.db_hostname}"
  }
}

resource "google_compute_instance" "app" {
  name         = "reddit-app-${count.index + 1}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]
  count        = "${var.instance_count}"

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.app_disk_image}"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"

    # использовать ephemeral IP для доступа из Интернет
    access_config {
      nat_ip = "${google_compute_address.app_ip.address}"
    }
  }

  metadata {
    # Путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  # # Подключение провиженоров к ВМ
  # connection {
  #   type  = "ssh"
  #   user  = "appuser"
  #   agent = false

  # # путь до приватного ключа
  #   private_key = "${file("~/.ssh/appuser")}"
  # }

  # provisioner "file" {
  #   content      = "${data.template_file.puma_service.rendered}"
  #   destination = "/tmp/puma.service"
  # }

  # provisioner "remote-exec" {
  #   script = "${path.module}/files/deploy.sh"
  # }
}

resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}

resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["9292", "80"]
  }

  # Каким адресам разрешать доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применения для инстансов с перечисленными тегами
  target_tags = ["reddit-app"]
}
