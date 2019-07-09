#use storage-bucket module
provider "google" {
  version = "2.0.0"
  project = "${var.project}"
  region = "${var.region}"
}

module "storage-bucket" {
  source = "SweetOps/storage-bucket/google"
  version = "0.1.1"
  # Имена поменяйте на другие
  name = ["sjay3-terraform-stage", "sjay3-terraform-prod"]
}

output storage-bucket_url {
  value = "${module.storage-bucket.url}"
}
