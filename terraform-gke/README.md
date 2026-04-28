# terraform-gke

Terraform configuration for a **simple zonal GKE cluster**: Google manages the control plane, and a dedicated node pool runs your worker nodes (default: **2**).

## Files

- `main.tf` – provider, `google_container_cluster` (zonal, default VPC, VPC-native / alias IPs), `google_container_node_pool`
- `variables.tf` – inputs with validation
- `outputs.tf` – cluster name, location, API endpoint, CA cert, node pool name, ready-to-run `gcloud` credentials command
- `terraform.tfvars.example` – example variable values
- `.gitignore` – excludes state, secrets, and `terraform.tfvars`

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) `>= 1.3.0`
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) (for `kubectl` auth after apply)
- GCP project with billing enabled and these APIs enabled:

  ```bash
  gcloud services enable container.googleapis.com compute.googleapis.com --project=<your-project>
  ```

- Application Default Credentials (typical for local use):

  ```bash
  gcloud auth application-default login
  ```

  For IAM, your user or service account needs roles such as **Kubernetes Engine Admin** and **Service Account User** (if using custom node SAs). See [GKE IAM](https://cloud.google.com/kubernetes-engine/docs/how-to/iam) for details.

## Quick start

1. Copy and edit variables:

   ```bash
   cd terraform-gke
   cp terraform.tfvars.example terraform.tfvars
   # Set project_id (and optionally region, zone, name_prefix, node_count, etc.)
   ```

2. Deploy:

   ```bash
   terraform init
   terraform apply
   ```

3. Configure `kubectl` (command is also printed as output `kubeconfig_command`):

   ```bash
   gcloud container clusters get-credentials <cluster-name> --zone=<zone> --project=<project-id>
   ```

   Or:

   ```bash
   terraform output -raw kubeconfig_command
   # run the printed command
   ```

4. Verify workers:

   ```bash
   kubectl get nodes
   ```

5. Destroy when done:

   ```bash
   terraform destroy
   ```

## Key variables

| Variable | Description |
|----------|-------------|
| `project_id` | GCP project ID (required) |
| `region` / `zone` | Provider region and zonal cluster location (default `us-central1` / `us-central1-a`) |
| `name_prefix` | Prefix for cluster and node pool names |
| `kubernetes_version` | Pin control plane version, or leave empty to use `release_channel` defaults |
| `release_channel` | `RAPID`, `REGULAR`, or `STABLE` (used when `kubernetes_version` is empty) |
| `node_count` | Worker count (1–10, default `2`) |
| `machine_type`, `disk_size_gb`, `disk_type` | Node VM shape and disk |
| `node_image_type` | e.g. `COS_CONTAINERD` |
| `node_service_account_email` | Optional; empty uses the default compute service account |
| `labels` | Kubernetes node labels |
| `tags` | GCE network tags on node VMs |

## Notes

- **Control plane**: GKE always runs the Kubernetes control plane for you. A **zonal** cluster has a single control-plane replica in the chosen zone (analogous to “one master” for learning setups). For higher control-plane availability, use a **regional** cluster (not included here).
- **Production**: consider a remote state backend (e.g. GCS with versioning), private clusters, Workload Identity, maintenance windows, and restricted `master_authorized_networks_config`—this module keeps defaults simple for learning and dev.
