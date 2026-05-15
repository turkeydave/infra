# Artifact Registry repository that holds all images for the
# ephemeral-runner POC: app, api, pubsub-relay, postgres-seeded,
# firebase-emulator-seeded, edge-proxy.
#
# sse-temp has its own separate repo (`temp-sse-poc`); this one is
# distinct.

resource "google_artifact_registry_repository" "ephemeral_runner" {
  location      = var.region
  repository_id = var.ephem_runner_repo_id
  description   = "Container images for the ephemeral runner POC"
  format        = "DOCKER"

  depends_on = [
    google_project_service.shared["artifactregistry.googleapis.com"],
  ]
}
