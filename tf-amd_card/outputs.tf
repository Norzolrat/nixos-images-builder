output "vm_id" {
  value       = proxmox_virtual_environment_vm.amd_gpu.vm_id
  description = "ID de la VM dans Proxmox"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.amd_gpu.name
  description = "Nom de la VM"
}

output "vm_ip" {
  value       = split("/", var.vm_ip)[0]
  description = "Adresse IP de la VM"
}

output "connection_info" {
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║           NixOS AMD GPU VM — Configuration                     ║
    ╚════════════════════════════════════════════════════════════════╝

    VM ID   : ${var.vm_id}
    Hostname: ${var.vm_hostname}
    IP      : ${split("/", var.vm_ip)[0]}
    GPU     : mapping/${var.gpu_pci_mapping}

    Connexion SSH :
      ssh ${var.manager_user}@${split("/", var.vm_ip)[0]}

    Vérifier la carte dans la VM :
      rocm-smi
      rocminfo | grep -i "gfx\|name"

    Test Python ROCm (si image ROCm dans Docker) :
      python3 -c "import subprocess; subprocess.run(['rocminfo'])"

    Logs cloud-init :
      sudo tail -f /var/log/cloud-init-output.log

  EOT
  description = "Informations de connexion à la VM AMD GPU"
}
