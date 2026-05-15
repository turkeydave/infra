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
  description = "Artifact Registry repo holding the preview-gateway image. Must match infra/shared/."
  default     = "ephemeral-runner"
}

variable "image_tag" {
  type        = string
  description = "Image tag for the Cloud Run services (preview-gateway + dispatcher). Bump and re-apply to roll both forward together."
}

variable "task_vm_image_tag" {
  type        = string
  description = "Image tag the dispatcher passes to each task VM via metadata. The VM uses this to pull postgres-seeded / firebase-emulator-seeded / pubsub-relay / edge-proxy from Artifact Registry. Independent of `image_tag` so the Cloud Run services and the per-VM platform images can roll at different cadences."
}

variable "task_vm_zone" {
  type        = string
  description = "Compute Engine zone the dispatcher creates task VMs in."
  default     = "us-central1-a"
}

variable "default_repo_url" {
  type        = string
  description = "Default git repo the dispatcher tells task VMs to clone."
  default     = "https://github.com/turkeydave/ephemeral.git"
}

variable "default_branch" {
  type        = string
  description = "Default branch the dispatcher tells task VMs to check out."
  default     = "main"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for ephemeral-runner resources (kept distinct from sse-temp)."
  default     = "ephem-runner"
}

variable "egress_subnet_cidr" {
  type        = string
  description = "Subnet CIDR for Cloud Run Direct VPC egress. Cloud Run requires at least a /26 (each instance burns one IP plus reserved overhead). Picked outside the default auto-mode range 10.128.0.0/9."
  default     = "10.10.0.0/26"
}

variable "vm_target_tag" {
  type        = string
  description = "Network tag set on M1 VMs (matches scripts/launch-vm.ps1)."
  default     = "ephem-runner-vm"
}

variable "dispatcher_invoker_members" {
  type        = list(string)
  description = "IAM principals (e.g. user:foo@example.com, group:bar@..., serviceAccount:...) allowed to invoke the dispatcher Cloud Run service. M4 swaps from `allUsers` to a tight list — typically just the human owner of the POC. The cleanup-CLI helper uses `gcloud auth print-identity-token` so any of these work without secrets."
  default     = []
}
