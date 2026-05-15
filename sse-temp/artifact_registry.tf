resource "google_artifact_registry_repository" "temp_poc" {
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  description   = "Artifact Registry for the temp SSE PoC"
  format        = "DOCKER"
}

