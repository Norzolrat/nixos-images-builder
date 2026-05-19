# ========================================
# Outputs
# ========================================

output "vm_ids" {
  value       = [for vm in proxmox_virtual_environment_vm.base : vm.vm_id]
  description = "IDs des VMs déployées"
}

output "vm_names" {
  value       = [for vm in proxmox_virtual_environment_vm.base : vm.name]
  description = "Noms des VMs déployées"
}

output "vm_ips" {
  value       = [for ip in local.vm_ips : split("/", ip)[0]]
  description = "Adresses IP des VMs déployées"
}

output "connection_info" {
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║              NixOS Base VMs — Configuration                    ║
    ╚════════════════════════════════════════════════════════════════╝

    ${join("\n    ", [for i in range(var.vm_count) : format(
      "- %-25s  ssh %s@%s",
      local.vm_hostnames[i],
      var.manager_user,
      split("/", local.vm_ips[i])[0]
    )])}

    Logs cloud-init (dans la VM) :
      sudo tail -f /var/log/cloud-init-output.log

  EOT
  description = "Informations de connexion aux VMs"
}
