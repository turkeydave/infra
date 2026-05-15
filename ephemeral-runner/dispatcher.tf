# Dispatcher Cloud Run service (M3).
#
# POST /environments mints an env_id, writes the Firestore registry doc,
# and creates a per-env task VM via the Compute Engine API.
#
# Ingress = ALL for the POC: dispatcher is publicly callable on its
# *.run.app URL with `allUsers` invoker. M4 will front it with IAP /
# token gating; for now treat the URL as a shared secret.
#
# Direct VPC egress is NOT needed — the dispatcher only talks to the
# Compute API + Firestore over standard Google APIs (no private IPs).

resource "google_cloud_run_v2_service" "dispatcher" {
  name     = "${var.name_prefix}-dispatcher"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    service_account = google_service_account.dispatcher.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ephem_runner_repo_id}/dispatcher:${var.image_tag}"

      ports {
        name           = "http1"
        container_port = 8080
      }

      # Cloud Run does NOT auto-set GOOGLE_CLOUD_PROJECT like App Engine
      # does, so we set it explicitly. The dispatcher's Compute API calls
      # need the project id, and the @google-cloud/firestore SDK reads
      # this env var first before falling back to metadata detection.
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "ZONE"
        value = var.task_vm_zone
      }
      env {
        name  = "TASK_VM_SA_EMAIL"
        value = google_service_account.task_vm.email
      }
      env {
        name  = "LB_IP_DASHED"
        value = replace(google_compute_global_address.preview.address, ".", "-")
      }
      env {
        name  = "DEFAULT_IMAGE_TAG"
        value = var.task_vm_image_tag
      }
      env {
        name  = "DEFAULT_REPO_URL"
        value = var.default_repo_url
      }
      env {
        name  = "DEFAULT_BRANCH"
        value = var.default_branch
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

# M4: dispatcher invocation no longer uses `allUsers`. Cloud Run only
# accepts Google-signed ID tokens (with aud=service-url) for IAM-gated
# invocation, and user accounts cannot mint such tokens directly. The
# canonical pattern for "let a human call a Cloud Run service from
# their laptop" is short-lived service-account impersonation:
#
#   1. We provision a dedicated `ephem-runner-cli-caller` SA below
#      (no permanent credentials, never downloaded as a key).
#   2. That SA is the run.invoker on the dispatcher service.
#   3. Each human listed in `dispatcher_invoker_members` is granted
#      `roles/iam.serviceAccountTokenCreator` on the SA, which lets
#      them ask the IAM API for a short-lived OIDC token *as* the SA
#      with the dispatcher URL as audience.
#   4. scripts/preview.ps1 calls
#        gcloud auth print-identity-token \
#          --impersonate-service-account=<cli-caller> \
#          --audiences=<dispatcher-url>
#      and sends the result as a Bearer token. Cloud Run validates the
#      aud + signature, IAM validates the principal.

resource "google_service_account" "cli_caller" {
  account_id   = "${var.name_prefix}-cli-caller"
  display_name = "Ephemeral runner CLI caller (impersonation target)"
  description  = "Impersonated by humans listed in dispatcher_invoker_members so they can mint Cloud-Run-bound ID tokens for the dispatcher."
}

resource "google_cloud_run_v2_service_iam_member" "cli_caller_invokes_dispatcher" {
  project  = google_cloud_run_v2_service.dispatcher.project
  location = google_cloud_run_v2_service.dispatcher.location
  name     = google_cloud_run_v2_service.dispatcher.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cli_caller.email}"
}

resource "google_service_account_iam_member" "humans_impersonate_cli_caller" {
  for_each           = toset(var.dispatcher_invoker_members)
  service_account_id = google_service_account.cli_caller.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}
