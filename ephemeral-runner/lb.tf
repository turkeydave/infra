# Global HTTP load balancer fronting the preview-gateway Cloud Run
# service via a serverless NEG.
#
# HTTP-only for the POC (nip.io path; no certs). When we move to a real
# domain in M5 we'll add a managed certificate + target_https_proxy and
# keep the URL map / backend / NEG as-is.
#
# Traffic path:
#   user --> global IP :80
#         --> google_compute_target_http_proxy
#         --> google_compute_url_map (default → backend)
#         --> google_compute_backend_service
#         --> google_compute_region_network_endpoint_group (CLOUD_RUN)
#         --> Cloud Run preview-gateway
#         --> Direct VPC egress
#         --> VM internal IP :8080

resource "google_compute_global_address" "preview" {
  name        = "${var.name_prefix}-preview-lb-ip"
  description = "Static global IPv4 for the ephemeral-runner preview LB."
}

resource "google_compute_region_network_endpoint_group" "preview_gateway_neg" {
  name                  = "${var.name_prefix}-preview-gw-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.preview_gateway.name
  }
}

resource "google_compute_backend_service" "preview_gateway" {
  name                  = "${var.name_prefix}-preview-gw-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.preview_gateway_neg.id
  }
}

resource "google_compute_url_map" "preview" {
  name            = "${var.name_prefix}-preview-url-map"
  default_service = google_compute_backend_service.preview_gateway.id
}

resource "google_compute_target_http_proxy" "preview" {
  name    = "${var.name_prefix}-preview-http-proxy"
  url_map = google_compute_url_map.preview.id
}

resource "google_compute_global_forwarding_rule" "preview_http" {
  name                  = "${var.name_prefix}-preview-fwd-http"
  target                = google_compute_target_http_proxy.preview.id
  port_range            = "80"
  ip_address            = google_compute_global_address.preview.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
