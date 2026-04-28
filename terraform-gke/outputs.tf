output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "Zone of the zonal cluster (matches var.zone)."
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public certificate used by kubectl to validate the cluster."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_pool_name" {
  description = "Name of the worker node pool."
  value       = google_container_node_pool.workers.name
}

output "kubeconfig_command" {
  description = "Ready-to-run gcloud command to fetch kubeconfig for kubectl."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
