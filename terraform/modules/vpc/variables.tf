#vpc variables
variable "source_ranges" {
  type = "string"
  description = "Source ranges for ssh firewall rule"
  default = ["0.0.0.0/0"]
}