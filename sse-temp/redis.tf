resource "google_redis_instance" "poc" {
  provider       = google-beta
  name           = "temp-sse-poc-redis"
  display_name   = "Temp SSE PoC Redis"
  region         = var.region
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  redis_version  = "REDIS_7_0"

  authorized_network = google_compute_network.poc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  secondary_ip_range = google_compute_global_address.private_services.name

  depends_on = [
    google_project_service.services["redis.googleapis.com"],
    google_service_networking_connection.private_services,
  ]

  lifecycle {
    ignore_changes = [
      secondary_ip_range,
    ]
  }
}
