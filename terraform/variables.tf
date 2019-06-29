# Terraform variables
variable "project" {
  type = "string"
  description = "Project ID"
}
variable "region" {
  type = "string"
  description = "region"
  default = "europe-west1"
}
variable "public_key_path" {
  type = "string"
  description = "Path to thee public key used for ssh access"
}
variable "disk_image" {
  type = "string"
  description = "Disk image"
}
