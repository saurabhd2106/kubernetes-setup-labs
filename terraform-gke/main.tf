terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_container_cluster" "primary" {
  name     = "${var.name_prefix}-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  dynamic "release_channel" {
    for_each = var.kubernetes_version == "" ? [1] : []
    content {
      channel = var.release_channel
    }
  }

  min_master_version = var.kubernetes_version != "" ? var.kubernetes_version : null

  # VPC-native cluster with auto-allocated secondary ranges on the default VPC.
  ip_allocation_policy {}
}

resource "google_container_node_pool" "workers" {
  name       = "${var.name_prefix}-workers"
  cluster    = google_container_cluster.primary.name
  location   = var.zone
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    image_type   = var.node_image_type
    oauth_scopes = var.node_oauth_scopes

    labels = var.labels
    tags   = var.tags

    service_account = var.node_service_account_email != "" ? var.node_service_account_email : null
  }
}
