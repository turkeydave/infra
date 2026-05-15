resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "jwt_secret" {
  provider  = google-beta
  secret_id = var.jwt_secret_name

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.services["secretmanager.googleapis.com"],
  ]
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  provider    = google-beta
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

resource "google_secret_manager_secret" "app_jwt_secret" {
  provider  = google-beta
  secret_id = var.app_jwt_secret_name

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.services["secretmanager.googleapis.com"],
  ]
}

resource "google_secret_manager_secret_version" "app_jwt_secret" {
  provider    = google-beta
  secret      = google_secret_manager_secret.app_jwt_secret.id
  secret_data = var.app_jwt_secret_value
}
