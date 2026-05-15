# Service accounts for the ephemeral-runner stack.
#
# Three SAs in M3, each scoped narrowly:
#
#   ephem-runner-preview-gateway
#       Cloud Run preview-gateway. Pulls its own image, writes logs/metrics,
#       and (new in M3) reads the Firestore env registry to resolve
#       <env_id> -> vm_internal_ip on every preview request.
#
#   ephem-runner-dispatcher
#       Cloud Run dispatcher. Mints env_ids, writes Firestore env registry
#       docs, and creates per-env task VMs via the Compute Engine API.
#       Needs `iam.serviceAccountUser` on the task-vm SA so it can attach
#       that SA to the VMs it launches.
#
#   ephem-runner-task-vm
#       Each ephemeral task VM runs as this SA. Needs to pull images from
#       Artifact Registry, ship logs/metrics, and update its own registry
#       doc with status/IP/ready_at when /healthz comes up.
#
# All Firestore writes target the (default) database in this project
# (FIRESTORE_NATIVE, us-central1). No DB resource needed — it already
# exists.

# --------------------------------------------------------------------------
# preview-gateway SA (existed in M2; M3 adds datastore.user)
# --------------------------------------------------------------------------

resource "google_service_account" "preview_gateway" {
  account_id   = "${var.name_prefix}-preview-gateway"
  display_name = "Ephemeral runner preview gateway (Cloud Run)"
  description  = "Reverse-proxies preview URLs to the current task VM. M3: Firestore env registry lookup."
}

resource "google_artifact_registry_repository_iam_member" "gateway_pulls_image" {
  project    = var.project_id
  location   = var.region
  repository = var.ephem_runner_repo_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.preview_gateway.email}"
}

resource "google_project_iam_member" "gateway_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.preview_gateway.email}"
}

resource "google_project_iam_member" "gateway_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.preview_gateway.email}"
}

# Read-only access is enough for the gateway, but `datastore.user` is the
# most narrowly-scoped predefined role that covers Firestore document
# reads. There is no built-in Firestore-read-only role; using
# `datastore.viewer` would also work but it's broader on the Datastore
# admin surface. We accept the small over-grant in exchange for
# minimizing custom roles.
resource "google_project_iam_member" "gateway_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.preview_gateway.email}"
}

# --------------------------------------------------------------------------
# dispatcher SA (M3 new)
# --------------------------------------------------------------------------

resource "google_service_account" "dispatcher" {
  account_id   = "${var.name_prefix}-dispatcher"
  display_name = "Ephemeral runner dispatcher (Cloud Run)"
  description  = "Mints env_ids, writes Firestore env registry, creates per-env task VMs."
}

resource "google_artifact_registry_repository_iam_member" "dispatcher_pulls_image" {
  project    = var.project_id
  location   = var.region
  repository = var.ephem_runner_repo_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.dispatcher.email}"
}

resource "google_project_iam_member" "dispatcher_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

resource "google_project_iam_member" "dispatcher_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

resource "google_project_iam_member" "dispatcher_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

# Create / start / stop / delete VMs and their disks in this project.
# `instanceAdmin.v1` covers create + delete + metadata updates; we need
# `compute.networkUser` so the dispatcher can attach the VM to the
# default subnet (the SA needs explicit permission on the subnet
# resource even when the dispatcher is in the same project).
resource "google_project_iam_member" "dispatcher_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

resource "google_project_iam_member" "dispatcher_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

# --------------------------------------------------------------------------
# task-vm SA (M3 new)
# --------------------------------------------------------------------------

resource "google_service_account" "task_vm" {
  account_id   = "${var.name_prefix}-task-vm"
  display_name = "Ephemeral runner task VM"
  description  = "Per-task Compute Engine VM SA. Pulls images, writes logs/metrics, updates its own registry doc."
}

resource "google_artifact_registry_repository_iam_member" "task_vm_pulls_image" {
  project    = var.project_id
  location   = var.region
  repository = var.ephem_runner_repo_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.task_vm.email}"
}

resource "google_project_iam_member" "task_vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.task_vm.email}"
}

resource "google_project_iam_member" "task_vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.task_vm.email}"
}

resource "google_project_iam_member" "task_vm_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.task_vm.email}"
}

# Dispatcher must be allowed to "actAs" the task-vm SA in order to
# attach it to a freshly-created VM.
resource "google_service_account_iam_member" "dispatcher_uses_task_vm_sa" {
  service_account_id = google_service_account.task_vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.dispatcher.email}"
}
