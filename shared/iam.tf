# Project-level IAM for the default Compute Engine service account, which
# is what every ephemeral-runner VM (Milestone 1 hand-launch and the M3
# dispatcher's `instances.create`) uses by default.
#
# Without these grants the VM startup script can:
#   - not pull from the `ephemeral-runner` Artifact Registry repo
#     (`Permission 'artifactregistry.repositories.downloadArtifacts' denied`)
#   - not write structured logs (cosmetic, but spams serial output)
#
# Long-term we'll move per-VM workloads onto a dedicated `ephem-task-vm`
# SA defined in `infra/ephemeral-runner/iam.tf`. For M1 we just unblock
# the default SA.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  default_compute_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

# Pull from the ephemeral-runner repo. Scoped to the repo (not project-
# wide) to keep blast radius small.
resource "google_artifact_registry_repository_iam_member" "default_compute_pulls_ephem_runner" {
  project    = var.project_id
  location   = google_artifact_registry_repository.ephemeral_runner.location
  repository = google_artifact_registry_repository.ephemeral_runner.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.default_compute_sa}"
}

# Write logs / metrics. Project-wide because Cloud Logging / Monitoring
# are project-scoped resources.
resource "google_project_iam_member" "default_compute_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.default_compute_sa}"
}

resource "google_project_iam_member" "default_compute_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${local.default_compute_sa}"
}
