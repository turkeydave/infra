output "artifact_registry_repository" {
  value = google_artifact_registry_repository.temp_poc.id
}

output "backend_url" {
  value = google_cloud_run_v2_service.backend.uri
}

output "gateway_url" {
  value = google_cloud_run_v2_service.gateway.uri
}

output "client_url" {
  value = google_cloud_run_v2_service.client.uri
}

output "redis_host" {
  value = google_redis_instance.poc.host
}

output "app_jwt_secret_name" {
  value = google_secret_manager_secret.app_jwt_secret.secret_id
}

output "jwt_secret_name" {
  value = google_secret_manager_secret.jwt_secret.secret_id
}
