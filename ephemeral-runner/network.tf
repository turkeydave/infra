# Direct VPC egress subnet for the preview-gateway Cloud Run service.
#
# Cloud Run "Direct VPC egress" needs a dedicated subnet in the same VPC
# as the destination workload. We attach the gateway to this subnet so
# its egress traffic gets a private RFC1918 source address inside the
# `default` VPC, which lets us write a tight firewall rule that allows
# only this subnet to reach VM:8080. The VM itself sits on the default
# auto-created subnet for us-central1.
#
# Sized /28 (16 IPs); Direct VPC egress can comfortably scale within
# that for the POC. Bump if we ever need more concurrency.

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_subnetwork" "gateway_egress" {
  name          = "${var.name_prefix}-gw-egress"
  description   = "Source subnet for preview-gateway Cloud Run direct VPC egress"
  ip_cidr_range = var.egress_subnet_cidr
  region        = var.region
  network       = data.google_compute_network.default.id

  # Required for Cloud Run direct VPC egress.
  private_ip_google_access = true
}
