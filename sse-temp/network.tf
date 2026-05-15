resource "google_project_service" "services" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "redis.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "poc" {
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.services["compute.googleapis.com"],
  ]
}

resource "google_compute_subnetwork" "poc" {
  name          = var.subnet_name
  network       = google_compute_network.poc.id
  ip_cidr_range = var.subnet_cidr
  region        = var.region

  depends_on = [
    google_project_service.services["compute.googleapis.com"],
  ]
}

resource "google_compute_global_address" "private_services" {
  provider      = google-beta
  name          = "${var.network_name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", var.private_services_cidr)[1])
  network       = google_compute_network.poc.id

  depends_on = [
    google_project_service.services["compute.googleapis.com"],
  ]
}

resource "google_service_networking_connection" "private_services" {
  provider                = google-beta
  network                 = google_compute_network.poc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  depends_on = [
    google_project_service.services["servicenetworking.googleapis.com"],
  ]
}
