terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  generate_key   = var.ssh_public_key == ""
  ssh_user       = var.ssh_user != "" ? var.ssh_user : "ubuntu"
  ssh_public_key = local.generate_key ? tls_private_key.ssh[0].public_key_openssh : var.ssh_public_key
  ssh_tag        = "${var.name_prefix}-ssh"
  vm_tags        = distinct(concat(var.tags, [local.ssh_tag]))
}

resource "tls_private_key" "ssh" {
  count     = local.generate_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private_key" {
  count           = local.generate_key ? 1 : 0
  filename        = "${path.module}/${var.name_prefix}-key.pem"
  content         = tls_private_key.ssh[0].private_key_pem
  file_permission = "0600"
}

resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
}

resource "google_compute_firewall" "ssh" {
  name        = "${var.name_prefix}-allow-ssh"
  network     = google_compute_network.vpc.name
  target_tags = [local.ssh_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
}

# Google Cloud Load Balancer health checks probe NodePort backends from these ranges.
# See: https://cloud.google.com/load-balancing/docs/health-checks#firewall_rules
resource "google_compute_firewall" "lb_healthchecks" {
  count   = var.enable_lb_healthcheck_firewall ? 1 : 0
  name    = "${var.name_prefix}-allow-lb-healthchecks"
  network = google_compute_network.vpc.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = local.vm_tags
}

locals {
  k8s_node_sa_roles = [
    "roles/compute.loadBalancerAdmin",
    "roles/compute.networkAdmin",
    "roles/compute.viewer",
  ]
  # Service account ID must be 6-30 chars; keep suffix "-k8s-node" (9 chars).
  k8s_node_account_id = "${substr(var.name_prefix, 0, 21)}-k8s-node"
}

resource "google_service_account" "k8s_nodes" {
  count        = var.attach_kubernetes_service_account ? 1 : 0
  account_id   = local.k8s_node_account_id
  display_name = "Kubernetes nodes (CCM / external LoadBalancer)"
  project      = var.project_id
}

resource "google_project_iam_member" "k8s_nodes" {
  for_each = var.attach_kubernetes_service_account ? toset(local.k8s_node_sa_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.k8s_nodes[0].email}"
}

resource "google_compute_instance" "vm" {
  count        = var.vm_count
  name         = "${var.name_prefix}-vm-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  metadata = {
    ssh-keys               = "${local.ssh_user}:${local.ssh_public_key}"
    block-project-ssh-keys = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = var.labels
  tags   = local.vm_tags

  dynamic "service_account" {
    for_each = var.attach_kubernetes_service_account ? [1] : []
    content {
      email  = google_service_account.k8s_nodes[0].email
      scopes = ["cloud-platform"]
    }
  }
}
