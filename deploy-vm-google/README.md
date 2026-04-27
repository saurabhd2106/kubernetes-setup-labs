# deploy-vm-google

Simple Terraform setup that creates a VPC, a subnet, basic firewall rules, and a configurable number of VMs all attached to the same network on Google Cloud.

## Files

- `main.tf` – provider, VPC, subnet, firewall rules, VMs
- `variables.tf` – configurable inputs
- `outputs.tf` – VM names and IPs
- `terraform.tfvars.example` – example variable values

## Usage

1. Copy the example tfvars and edit it:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Authenticate with GCP (one of):

   ```bash
   gcloud auth application-default login
   # or
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
   ```

3. Deploy:

   ```bash
   terraform init
   terraform apply
   ```

4. Destroy when done:

   ```bash
   terraform destroy
   ```

## Key variables

- `vm_count` – number of VMs to create (all in the same VPC/subnet)
- `machine_type`, `image`, `disk_size_gb` – VM size and OS
- `subnet_cidr` – internal IP range shared by all VMs
- `assign_public_ip` – whether each VM gets an external IP
- `ssh_user` / `ssh_public_key` – optional SSH key injection
- `ssh_source_ranges` – CIDRs allowed to SSH (default `0.0.0.0/0`; restrict for production)

All VMs can reach each other freely on the subnet via the `allow-internal` firewall rule.
