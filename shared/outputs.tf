output "project_id" {
  value       = var.project_id
  description = "Personal GCP project ID."
}

output "region" {
  value       = var.region
  description = "Default region."
}

output "ephem_runner_registry" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ephemeral_runner.repository_id}"
  description = "Full Docker registry path for the ephemeral-runner repo. Use as <registry>/<image>:<tag>."
}
