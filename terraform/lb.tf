# load balancer configuration
# Create instanse group
resource "google_compute_instance_group" "reddit-app" {
  name = "reddit-app"
  description = "Reddip app instanse group"
  zone = "${var.zone}"
  instances = [ "${google_compute_instance.app.self_link}" ]
}
