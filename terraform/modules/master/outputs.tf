# ========================================
# Outputs
# ========================================

output "vm_id" {
  value       = proxmox_virtual_environment_vm.master.vm_id
  description = "ID de la VM"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.master.name
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

# ========================================
# Helper
# ========================================
#
# Logs cloud-init dans la VM :
#   sudo tail -f /var/log/cloud-init-output.log
#
# Logs kubeadm :
#   cat /root/kubeadm-init.log
#
# Récupérer le kubeconfig :
#   scp <user>@<master-ip>:~/kubeconfig ~/.kube/config
#
# Permissions snippets sur Proxmox :
#   chown -R root:www-data /var/lib/pve/local-btrfs/snippets
#   chmod 775 /var/lib/pve/local-btrfs/snippets
