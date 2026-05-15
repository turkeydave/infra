output "preview_lb_ip" {
  value       = google_compute_global_address.preview.address
  description = "Public IPv4 of the preview LB. Use as <env>-app.<ip-dashed>.nip.io and <env>-api.<ip-dashed>.nip.io."
}

output "preview_lb_ip_dashed" {
  value       = replace(google_compute_global_address.preview.address, ".", "-")
  description = "Same IP, dashes — drop straight into nip.io URLs."
}

output "preview_gateway_url" {
  value       = google_cloud_run_v2_service.preview_gateway.uri
  description = "Cloud Run service URL (NOT publicly reachable — ingress is restricted to LB)."
}

output "preview_gateway_sa" {
  value       = google_service_account.preview_gateway.email
  description = "Service account the gateway runs as."
}

output "egress_subnet_cidr" {
  value       = google_compute_subnetwork.gateway_egress.ip_cidr_range
  description = "CIDR allowed to reach VM:8080 by the new firewall rule."
}

output "dispatcher_url" {
  value       = google_cloud_run_v2_service.dispatcher.uri
  description = "Public dispatcher URL. POST /environments to mint a new env."
}

output "dispatcher_sa" {
  value       = google_service_account.dispatcher.email
  description = "Service account the dispatcher runs as."
}

output "cli_caller_sa" {
  value       = google_service_account.cli_caller.email
  description = "Service account that CLI users impersonate to mint dispatcher-bound ID tokens."
}

output "task_vm_sa" {
  value       = google_service_account.task_vm.email
  description = "Service account attached to each per-env task VM."
}

output "cleanup_url" {
  value       = google_cloud_run_v2_service.cleanup.uri
  description = "Internal cleanup-worker URL (only invokable by the scheduler SA / over Direct VPC)."
}

output "cleanup_sa" {
  value       = google_service_account.cleanup.email
  description = "Service account the cleanup worker runs as."
}
