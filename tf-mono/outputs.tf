# ========================================
# Outputs - kubeadm Master
# ========================================

output "master_vm_id" {
  value       = module.master.vm_id
  description = "ID de la VM Master"
}

output "master_vm_name" {
  value       = module.master.vm_name
  description = "Nom de la VM Master"
}

output "master_vm_ip" {
  value       = var.vm_ip
  description = "IP de la VM Master"
}

# ========================================
# Output d'aide
# ========================================

output "deployment_info" {
  value       = module.deployment.deployment_info
  description = "Résumé des déploiements hello-world (Mario / Star Wars / Matrix)"
}


output "cluster_info" {
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║           kubeadm Cluster (NixOS) — Configuration             ║
    ╚════════════════════════════════════════════════════════════════╝

    Master Node:
      - Hostname : ${var.vm_hostname}-master
      - IP       : ${var.vm_ip}
      - SSH      : ssh ${var.manager_user}@${split("/", var.vm_ip)[0]}

    Récupérer le kubeconfig :
      scp ${var.manager_user}@${split("/", var.vm_ip)[0]}:~/kubeconfig ~/.kube/config
      kubectl get nodes

    Logs cloud-init (dans la VM) :
      sudo tail -f /var/log/cloud-init-output.log

  EOT
  description = "Informations de connexion au cluster"
}
