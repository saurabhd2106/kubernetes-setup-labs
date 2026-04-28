variable "project_id" {
  description = "GCP project ID."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region for the VPC and subnet."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the VMs."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix used for naming all resources. Lowercase letters, digits, and hyphens; start with a letter."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 chars, lowercase, start with a letter, and contain only [a-z0-9-]."
  }
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr must be a valid CIDR block (e.g. 10.10.0.0/24)."
  }
}

variable "vm_count" {
  description = "Number of VMs to create (all in the same VPC/subnet)."
  type        = number
  default     = 2

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 50
    error_message = "vm_count must be between 1 and 50."
  }
}

variable "machine_type" {
  description = "Machine type for the VMs."
  type        = string
  default     = "e2-medium"
}

variable "image" {
  description = "Boot image for the VMs. Default is Ubuntu 24.04 LTS (amd64). For Arm (e.g. t2a-*), use ubuntu-os-cloud/ubuntu-2404-lts-arm64."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 2000
    error_message = "disk_size_gb must be between 10 and 2000."
  }
}

variable "assign_public_ip" {
  description = "Whether to assign an ephemeral public IP to each VM."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "Source CIDR ranges allowed to SSH to the VMs. Restrict for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_user" {
  description = "SSH username injected on the VMs."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key contents to inject. If empty, Terraform will generate a new keypair and write the private key to ./<name_prefix>-key.pem."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional network tags to apply to the VMs (the SSH tag is added automatically)."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to the VMs (useful for cost tracking)."
  type        = map(string)
  default     = {}
}

variable "enable_lb_healthcheck_firewall" {
  description = "Allow GCP load balancer health check ranges (130.211.0.0/22, 35.191.0.0/16) to reach NodePorts 30000-32767 on tagged instances. Required for Service type=LoadBalancer with GCP CCM."
  type        = bool
  default     = true
}

variable "attach_kubernetes_service_account" {
  description = "Create a dedicated GCP service account with LB/network IAM roles and attach it to VMs with cloud-platform scope (recommended for kubernetes/cloud-provider-gcp)."
  type        = bool
  default     = true
}
