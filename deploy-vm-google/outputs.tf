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
  description = "External (public) IPs of the VMs (empty when assign_public_ip = false)."
  value = [
    for vm in google_compute_instance.vm :
    try(vm.network_interface[0].access_config[0].nat_ip, "")
  ]
}

output "ssh_user" {
  description = "Username used for SSH."
  value       = local.ssh_user
}

output "ssh_private_key_path" {
  description = "Path to the generated private key (empty when ssh_public_key is supplied)."
  value       = local.generate_key ? local_sensitive_file.ssh_private_key[0].filename : ""
}

output "ssh_public_key" {
  description = "Public key injected into the VMs."
  value       = local.ssh_public_key
  sensitive   = true
}

output "ssh_commands" {
  description = "Ready-to-run SSH commands, one per VM."
  value = [
    for vm in google_compute_instance.vm :
    local.generate_key
    ? "ssh -i ${var.name_prefix}-key.pem ${local.ssh_user}@${try(vm.network_interface[0].access_config[0].nat_ip, vm.network_interface[0].network_ip)}"
    : "ssh ${local.ssh_user}@${try(vm.network_interface[0].access_config[0].nat_ip, vm.network_interface[0].network_ip)}"
  ]
}
