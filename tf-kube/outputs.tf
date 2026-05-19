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
# Outputs - kubeadm Workers
# ========================================

output "workers_count" {
  value       = var.worker_count
  description = "Nombre de workers déployés"
}

output "workers_vm_ids" {
  value       = [for w in module.worker : w.vm_id]
  description = "IDs des VMs workers"
}

output "workers_vm_ips" {
  value       = [for w in module.worker : w.vm_ip]
  description = "IPs des VMs workers"
}

# ========================================
# Output d'aide
# ========================================

output "cluster_info" {
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║           kubeadm Cluster (NixOS) — Configuration             ║
    ╚════════════════════════════════════════════════════════════════╝

    Master Node:
      - Hostname : ${var.vm_hostname}-master
      - IP       : ${var.vm_ip}
      - SSH      : ssh ${var.manager_user}@${split("/", var.vm_ip)[0]}

    Worker Nodes (${var.worker_count}):
      ${join("\n      ", [for i in range(var.worker_count) : format(
        "- %s-worker-%d: %s.%s.%s.%d/%s",
        var.vm_hostname,
        i + 1,
        split(".", split("/", var.vm_ip)[0])[0],
        split(".", split("/", var.vm_ip)[0])[1],
        split(".", split("/", var.vm_ip)[0])[2],
        tonumber(split(".", split("/", var.vm_ip)[0])[3]) + i + 1,
        split("/", var.vm_ip)[1]
      )])}

    Récupérer le kubeconfig :
      scp ${var.manager_user}@${split("/", var.vm_ip)[0]}:~/kubeconfig ~/.kube/config
      kubectl get nodes

    Logs cloud-init (dans la VM) :
      sudo tail -f /var/log/cloud-init-output.log

  EOT
  description = "Informations de connexion au cluster"
}
