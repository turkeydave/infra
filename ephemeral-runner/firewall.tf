# Allow the preview-gateway egress subnet to reach the M1 VM on :8080.
#
# This is the *narrow* replacement for the wide-open
# `ephem-runner-allow-edge-8080` rule that scripts/launch-vm.ps1 created
# during M1 (which allows tcp:8080 from 0.0.0.0/0). After M2 verifies
# end-to-end, the wide-open rule should be removed manually:
#
#   gcloud compute firewall-rules delete ephem-runner-allow-edge-8080 ^
#     --project=<project> --quiet
#
# Once the wide rule is gone, the VM is reachable on :8080 *only* from
# the gateway egress subnet (i.e. only via the LB → gateway path).

resource "google_compute_firewall" "gateway_to_vm_8080" {
  name        = "${var.name_prefix}-gw-to-vm-8080"
  network     = data.google_compute_network.default.name
  description = "Allow preview-gateway Cloud Run egress to reach ephem-runner-vm tagged VMs on :8080."
  direction   = "INGRESS"

  source_ranges = [google_compute_subnetwork.gateway_egress.ip_cidr_range]
  target_tags   = [var.vm_target_tag]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}
