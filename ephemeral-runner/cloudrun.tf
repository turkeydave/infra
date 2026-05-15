# Preview gateway Cloud Run service.
#
# - Ingress is restricted to the load balancer only — direct
#   `*.run.app` URLs cannot reach it. The only way in is the global LB.
# - Direct VPC egress through the dedicated /26 subnet so the gateway can
#   reach the VM's private IP.
# - Resolves <env_id> -> vm_internal_ip via the Firestore env registry
#   (5s in-process cache); enforces the per-env access_token via
#   cookie/query auth.
#
# Re-deploy by bumping `image_tag` in terraform.tfvars (after a new
# scripts/build-and-push.ps1 run) and re-applying.

resource "google_cloud_run_v2_service" "preview_gateway" {
  name     = "${var.name_prefix}-preview-gateway"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  # Throwaway POC service — let `terraform destroy` actually destroy it.
  deletion_protection = false

  template {
    service_account = google_service_account.preview_gateway.email

    # Direct VPC egress — Cloud Run gets a NIC inside our default VPC,
    # sourced from the gateway-egress /28. ALL_TRAFFIC because we want
    # the VM IP (RFC1918) reachable, not just private Google access.
    vpc_access {
      network_interfaces {
        network    = data.google_compute_network.default.id
        subnetwork = google_compute_subnetwork.gateway_egress.id
      }
      egress = "ALL_TRAFFIC"
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 4
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ephem_runner_repo_id}/preview-gateway:${var.image_tag}"

      ports {
        name           = "http1"
        container_port = 8080
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

# Allow unauthenticated invocations on the Cloud Run service. Combined
# with `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, this means anyone can
# call the service *via the LB* but not via the *.run.app URL — there
# is no *.run.app URL exposed to the public.
#
# When IAP comes in (M4), this can stay as-is; IAP enforces auth at the
# LB layer.
resource "google_cloud_run_v2_service_iam_member" "preview_gateway_invoker" {
  project  = google_cloud_run_v2_service.preview_gateway.project
  location = google_cloud_run_v2_service.preview_gateway.location
  name     = google_cloud_run_v2_service.preview_gateway.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
