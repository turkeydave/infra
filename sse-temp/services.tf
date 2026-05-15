resource "google_service_account" "backend" {
  account_id   = "temp-sse-backend"
  display_name = "Temp SSE Backend"
}

resource "google_service_account" "gateway" {
  account_id   = "temp-sse-gateway"
  display_name = "Temp SSE Gateway"
}

resource "google_secret_manager_secret_iam_member" "backend_jwt_accessor" {
  provider  = google-beta
  secret_id = google_secret_manager_secret.jwt_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_secret_manager_secret_iam_member" "backend_app_jwt_accessor" {
  provider  = google-beta
  secret_id = google_secret_manager_secret.app_jwt_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_secret_manager_secret_iam_member" "gateway_jwt_accessor" {
  provider  = google-beta
  secret_id = google_secret_manager_secret.jwt_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gateway.email}"
}

resource "google_cloud_run_v2_service" "backend" {
  provider = google-beta
  name     = var.backend_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.backend.email
    timeout         = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.backend_image

      env {
        name = "APP_JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SSE_JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "APP_JWT_ISSUER"
        value = "temp-browser-client"
      }

      env {
        name  = "APP_JWT_AUDIENCE"
        value = "temp-backend"
      }

      env {
        name  = "SSE_GATEWAY_BASE_URL"
        value = google_cloud_run_v2_service.gateway.uri
      }

      env {
        name  = "SSE_JWT_ISSUER"
        value = "temp-backend"
      }

      env {
        name  = "SSE_JWT_AUDIENCE"
        value = "temp-sse-gateway"
      }

      env {
        name  = "SSE_JWT_TTL_SECONDS"
        value = "1200"
      }

      env {
        name  = "SSE_JWT_REFRESH_AFTER_SECONDS"
        value = "1080"
      }

      env {
        name  = "REDIS_HOST"
        value = google_redis_instance.poc.host
      }

      env {
        name  = "REDIS_PORT"
        value = tostring(google_redis_instance.poc.port)
      }
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.poc.name
        subnetwork = google_compute_subnetwork.poc.name
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.backend_jwt_accessor,
    google_secret_manager_secret_iam_member.backend_app_jwt_accessor,
    google_redis_instance.poc,
  ]
}

resource "google_cloud_run_v2_service" "gateway" {
  provider = google-beta
  name     = var.gateway_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.gateway.email
    timeout         = "3600s"
    max_instance_request_concurrency = 50

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.gateway_image

      env {
        name = "SSE_JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "SSE_ALLOWED_ORIGINS"
        value = join(",", var.allowed_origins)
      }

      env {
        name  = "SSE_JWT_ISSUER"
        value = "temp-backend"
      }

      env {
        name  = "SSE_JWT_AUDIENCE"
        value = "temp-sse-gateway"
      }

      env {
        name  = "REDIS_HOST"
        value = google_redis_instance.poc.host
      }

      env {
        name  = "REDIS_PORT"
        value = tostring(google_redis_instance.poc.port)
      }
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.poc.name
        subnetwork = google_compute_subnetwork.poc.name
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.gateway_jwt_accessor,
    google_redis_instance.poc,
  ]
}

resource "google_cloud_run_v2_service" "client" {
  provider = google-beta
  name     = var.client_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    timeout = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.client_image

      env {
        name  = "BACKEND_BASE_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      env {
        name  = "DEFAULT_APP_JWT_SECRET"
        value = var.app_jwt_secret_value
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_service.backend,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "backend_invoker" {
  provider = google-beta
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "gateway_invoker" {
  provider = google-beta
  location = var.region
  name     = google_cloud_run_v2_service.gateway.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "client_invoker" {
  provider = google-beta
  location = var.region
  name     = google_cloud_run_v2_service.client.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
