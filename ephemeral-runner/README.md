# ephemeral-runner Terraform stack

Per the [POC plan](../../ephemeral/POC-Implementation-Plan.md), this stack
holds the agentic ephemeral runner cloud infrastructure.

**Status: M2 in progress.** Currently provisions:

- `ephem-runner-preview-gateway` SA + IAM
- `ephem-runner-gw-egress` /28 subnet (Cloud Run Direct VPC egress)
- `ephem-runner-gw-to-vm-8080` firewall rule (egress subnet → VM:8080)
- `ephem-runner-preview-gateway` Cloud Run service (LB-ingress only)
- Global HTTP LB: static IP + serverless NEG + backend + URL map +
  HTTP proxy + forwarding rule

Future milestones populate:

- M3: Firestore registry + Cloud Run dispatcher + IAM grants for it
- M4: Cleanup worker + IAP on the LB
- M5: Pub/Sub front-door for the dispatcher

Apply order:

1. [`infra/shared/`](../shared/) — must be applied first (Artifact Registry repo)
2. `infra/ephemeral-runner/` — this stack
