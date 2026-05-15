# Enable Google Cloud APIs used across stacks.
#
# These are project-scoped singletons. We use disable_on_destroy = false so
# they aren't disabled when this stack is destroyed (other stacks may still
# need them, and re-enabling APIs takes minutes).
#
# sse-temp/ also declares some of these (compute, run, secretmanager, etc.)
# in its own state. That's fine: enabling an already-enabled API is a no-op
# in Google Cloud. The disable_on_destroy = false on both sides prevents
# either stack from accidentally turning the API off.

resource "google_project_service" "shared" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
