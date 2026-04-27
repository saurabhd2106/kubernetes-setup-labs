output "vpc_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet."
  value       = google_compute_subnetwork.subnet.name
}

output "vm_names" {
  description = "Names of the created VMs."
  value       = google_compute_instance.vm[*].name
}

output "vm_internal_ips" {
  description = "Internal IPs of the VMs."
  value       = google_compute_instance.vm[*].network_interface[0].network_ip
}

output "vm_external_ips" {
  description = "External IPs of the VMs (empty if assign_public_ip = false)."
  value = [
    for vm in google_compute_instance.vm :
    try(vm.network_interface[0].access_config[0].nat_ip, "")
  ]
}
