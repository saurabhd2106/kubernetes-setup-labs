variable "project_id" {
  description = "GCP project ID."
  type        = string
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
  description = "Prefix used for naming all resources."
  type        = string
  default     = "demo"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "vm_count" {
  description = "Number of VMs to create."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for the VMs."
  type        = string
  default     = "e2-medium"
}

variable "image" {
  description = "Boot image for the VMs."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 20
}

variable "assign_public_ip" {
  description = "Whether to assign an ephemeral public IP to each VM."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "Source CIDR ranges allowed to SSH to the VMs."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_user" {
  description = "SSH username for the VMs (optional)."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key contents to add to the VMs (optional)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Network tags to apply to the VMs."
  type        = list(string)
  default     = []
}
