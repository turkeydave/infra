variable "project_id" {
  type        = string
  description = "Personal GCP project ID."
}

variable "region" {
  type        = string
  description = "Default region for region-scoped resources."
  default     = "us-central1"
}

variable "ephem_runner_repo_id" {
  type        = string
  description = "Artifact Registry repository ID for the ephemeral-runner POC images."
  default     = "ephemeral-runner"
}
