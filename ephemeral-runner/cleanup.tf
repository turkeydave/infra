# Cleanup worker (M4).
#
# Cloud Scheduler hits the cleanup Cloud Run service every 5 minutes.
# The service scans agent_environments for any doc with expires_at <= now
# (and status != "deleted"), deletes the corresponding Compute Engine
# VM, and marks the doc deleted.
#
# Two service accounts:
#
#   ephem-runner-cleanup
#       The cleanup Cloud Run service runs as this SA. It needs to delete
#       VMs (compute.instanceAdmin.v1) and update the registry doc
#       (datastore.user).
#
#   ephem-runner-scheduler
#       Cloud Scheduler authenticates outbound requests as this SA. It
#       needs run.invoker on the cleanup service so its POST /run
#       requests are accepted with a valid OIDC token. (Cleanup ingress
#       is INTERNAL_AND_CLOUD_LOAD_BALANCING — no public access.)

# --------------------------------------------------------------------------
# cleanup SA + roles
# --------------------------------------------------------------------------

resource "google_service_account" "cleanup" {
  account_id   = "${var.name_prefix}-cleanup"
  display_name = "Ephemeral runner cleanup worker (Cloud Run)"
  description  = "Reaps expired task VMs and marks Firestore registry docs deleted."
}

resource "google_artifact_registry_repository_iam_member" "cleanup_pulls_image" {
  project    = var.project_id
  location   = var.region
  repository = var.ephem_runner_repo_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cleanup.email}"
}

resource "google_project_iam_member" "cleanup_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cleanup.email}"
}

resource "google_project_iam_member" "cleanup_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cleanup.email}"
}

resource "google_project_iam_member" "cleanup_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.cleanup.email}"
}

resource "google_project_iam_member" "cleanup_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cleanup.email}"
}

# --------------------------------------------------------------------------
# scheduler SA + invoker permission on the cleanup service
# --------------------------------------------------------------------------

resource "google_service_account" "scheduler" {
  account_id   = "${var.name_prefix}-scheduler"
  display_name = "Ephemeral runner Cloud Scheduler"
  description  = "Used by Cloud Scheduler to invoke the cleanup Cloud Run service with an OIDC token."
}

# --------------------------------------------------------------------------
# Cloud Run service
# --------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "cleanup" {
  name     = "${var.name_prefix}-cleanup"
  location = var.region

  # No public access — INTERNAL_ONLY permits same-project VPC traffic
  # *and* same-project Google services (Cloud Scheduler / Pub/Sub /
  # Eventarc), which is exactly what we need: the scheduler invokes
  # /run, nothing else can. The run.invoker IAM check on the scheduler
  # SA is the second line of defense.
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  deletion_protection = false

  template {
    service_account = google_service_account.cleanup.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ephem_runner_repo_id}/cleanup:${var.image_tag}"

      ports {
        name           = "http1"
        container_port = 8080
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "ZONE"
        value = var.task_vm_zone
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 1
        period_seconds        = 5
        failure_threshold     = 6
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invokes_cleanup" {
  project  = google_cloud_run_v2_service.cleanup.project
  location = google_cloud_run_v2_service.cleanup.location
  name     = google_cloud_run_v2_service.cleanup.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# --------------------------------------------------------------------------
# Cloud Scheduler job — POST /run every 5 minutes
# --------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "cleanup_sweep" {
  name        = "${var.name_prefix}-cleanup-sweep"
  region      = var.region
  description = "Invokes the ephemeral-runner cleanup worker every 5 minutes."
  schedule    = "*/5 * * * *"
  time_zone   = "UTC"

  attempt_deadline = "60s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_v2_service.cleanup.uri}/run"

    oidc_token {
      service_account_email = google_service_account.scheduler.email
      audience              = google_cloud_run_v2_service.cleanup.uri
    }
  }
}
