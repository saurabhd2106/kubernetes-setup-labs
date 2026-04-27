# deploy-vm-google

Simple Terraform setup that creates a VPC, a subnet, basic firewall rules, and a configurable number of VMs all attached to the same network on Google Cloud. An SSH keypair is generated automatically (or you can supply your own), and the public IPs and ready-to-run `ssh` commands are returned as outputs.

## Files

- `main.tf` – provider, VPC, subnet, firewall rules, VMs, optional auto-generated SSH keypair
- `variables.tf` – configurable inputs (with validation)
- `outputs.tf` – VM names, IPs, SSH user/key/path, ready-to-run SSH commands
- `terraform.tfvars.example` – example variable values
- `.gitignore` – excludes state, secrets, generated keys, and tfvars
- `USER_GUIDE.md` – beginner-friendly walkthrough of the whole project
- `AUTH_GUIDE.md` – step-by-step GCP authentication and IAM setup

## Quick start

1. Set up GCP auth (see [AUTH_GUIDE.md](AUTH_GUIDE.md)):

   ```bash
   gcloud auth application-default login
   gcloud services enable compute.googleapis.com --project=<your-project>
   ```

2. Copy the example tfvars and edit it:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Deploy:

   ```bash
   terraform init
   terraform apply
   ```

4. Connect to a VM:

   ```bash
   terraform output -raw ssh_commands
   ```

   Run one of the printed commands.

5. Destroy when done:

   ```bash
   terraform destroy
   ```

## Key variables

- `vm_count` – number of VMs to create (all in the same VPC/subnet)
- `machine_type`, `image`, `disk_size_gb` – VM size and OS
- `subnet_cidr` – internal IP range shared by all VMs
- `assign_public_ip` – whether each VM gets an external IP
- `ssh_user` / `ssh_public_key` – SSH user and (optional) key
- `ssh_source_ranges` – CIDRs allowed to SSH (default `0.0.0.0/0`; restrict for production)
- `tags`, `labels` – network tags and resource labels

## SSH access

- If `ssh_public_key` is empty (default), Terraform generates a 4096-bit RSA keypair and writes the private key to `./<name_prefix>-key.pem` (mode `0600`).
- The public key is injected into every VM via the `ssh-keys` metadata.
- After `terraform apply`, run:

  ```bash
  terraform output ssh_commands
  ```

  to get a list of `ssh -i <key>.pem <user>@<public-ip>` commands.

- If you set `ssh_public_key` to your own key contents, no file is written and the commands omit `-i`.
- `terraform destroy` removes the generated `.pem` file.

## Best practices applied

- Provider versions pinned (`google ~> 5.0`, `tls ~> 4.0`, `local ~> 2.5`).
- Input validation on `project_id`, `name_prefix`, `subnet_cidr`, `vm_count`, `disk_size_gb`.
- SSH firewall scoped via `target_tags` so it only opens port 22 on these VMs, not the whole network.
- VM metadata sets `block-project-ssh-keys = "TRUE"` to prevent project-wide keys from leaking onto these VMs.
- Shielded VM enabled (`secure_boot`, `vTPM`, `integrity_monitoring`).
- Public key output is marked `sensitive`; private key is stored via `local_sensitive_file`.
- `.gitignore` excludes state files, `*.pem`, service-account JSON keys, and `terraform.tfvars`.
- For production, use a remote backend (e.g. GCS bucket with versioning) instead of local state.

## Learn more

- [USER_GUIDE.md](USER_GUIDE.md) – plain-language walkthrough of every file and step.
- [AUTH_GUIDE.md](AUTH_GUIDE.md) – GCP authentication and IAM setup.
