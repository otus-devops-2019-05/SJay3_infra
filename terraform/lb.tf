# load balancer configuration
# Create instanse group
resource "google_compute_instance_group" "reddit-app" {
  name = "reddit-app"
  description = "Reddip app instanse group"
  zone = "${var.zone}"
  instances = [ "${google_compute_instance.app.self_link}" ]

  named_port {
    name = "http"
    port = "9292"
  }
}

# Create backend for lb
resource "google_compute_backend_service" "reddit-app" {
  name = "reddit-backend"
  port_name = "http"
  protocol = "HTTP"

  backend {
    group = "${google_compute_instance_group.reddit-app.self_link}"
  }

  health_checks = [ "${google_compute_http_health_check.reddit-health.self_link}" ]
}

# add health check
resource "google_compute_http_health_check" "reddit-health" {
  name = "reddit-health"
  request_path = "/"
  port = "9292"
}

# create urlmap
resource "google_compute_url_map" "reddit-urlmap" {
  name = "reddit-urlmap"
  description = "a URL map for reddit application"
  default_service = "${google_compute_backend_service.reddit-app.self_link}"
}

#create target proxy to urlmap
resource "google_compute_target_http_proxy" "reddit-app" {
  name = "reddit-app-target-proxy"
  url_map = "${google_compute_url_map.reddit-urlmap.self_link}"
}

#Create forward rule to forward http to proxy
resource "google_compute_global_forwarding_rule" "redit-lb" {
  name = "reddit-lb"
  target = "${google_compute_target_http_proxy.reddit-app.self_link}"
  port_range = "80"
}
