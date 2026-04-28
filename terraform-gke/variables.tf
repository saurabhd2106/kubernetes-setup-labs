variable "project_id" {
  description = "GCP project ID."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region (used by the provider; cluster is zonal)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the zonal cluster and node pool."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix used for naming the cluster and node pool. Lowercase letters, digits, hyphens; start with a letter."
  type        = string
  default     = "gke-demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 chars, lowercase, start with a letter, and contain only [a-z0-9-]."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane (e.g. 1.29.6-gke.xxx). Leave empty to use the release channel default."
  type        = string
  default     = ""
}

variable "release_channel" {
  description = "Release channel used when kubernetes_version is not set."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "node_count" {
  description = "Number of worker nodes in the node pool."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "node_count must be between 1 and 10."
  }
}

variable "machine_type" {
  description = "Machine type for worker nodes."
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size for each worker node (GB)."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 2000
    error_message = "disk_size_gb must be between 10 and 2000."
  }
}

variable "disk_type" {
  description = "Boot disk type for worker nodes (e.g. pd-standard, pd-balanced, pd-ssd)."
  type        = string
  default     = "pd-standard"
}

variable "node_image_type" {
  description = "Node image type (COS with containerd is recommended)."
  type        = string
  default     = "COS_CONTAINERD"
}

variable "node_service_account_email" {
  description = "Service account email for nodes. Empty uses the project's default compute service account."
  type        = string
  default     = ""
}

variable "node_oauth_scopes" {
  description = "OAuth scopes for node VMs."
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "labels" {
  description = "Kubernetes labels applied to each node (visible in kubectl get nodes --show-labels)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags applied to worker node VMs (for firewall rules)."
  type        = list(string)
  default     = []
}
