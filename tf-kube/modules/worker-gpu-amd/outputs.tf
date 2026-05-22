output "vm_id" {
  value       = proxmox_virtual_environment_vm.worker.vm_id
  description = "ID de la VM"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.worker.name
  description = "Nom de la VM"
}

output "vm_ip" {
  value       = var.vm_ip
  description = "IP de la VM"
}

output "cloud_init_file_id" {
  value       = proxmox_virtual_environment_file.cloud_init_config.id
  description = "ID du snippet cloud-init sur Proxmox"
}
