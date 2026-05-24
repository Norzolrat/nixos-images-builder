# ========================================
# Outputs — hello-world deployments
# ========================================

output "namespace" {
  value       = kubernetes_namespace_v1.hello_world.metadata[0].name
  description = "Namespace Kubernetes utilisé"
}

output "app1_service_node_port" {
  value       = var.app1_node_port
  description = "NodePort de l'application 1 (thème Océan 🌍)"
}

output "app2_service_node_port" {
  value       = var.app2_node_port
  description = "NodePort de l'application 2 (thème Cosmos 🚀)"
}

output "deployment_info" {
  description = "Résumé du déploiement et URLs d'accès"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║        hello-world — Déploiements Kubernetes (nginx)          ║
    ╚════════════════════════════════════════════════════════════════╝

    Namespace  : ${kubernetes_namespace_v1.hello_world.metadata[0].name}
    Replicas   : ${var.replicas} par application

    ┌─ App 1 — Thème Océan 🌍 ────────────────────────────────────┐
    │  Deployment : hello-app1                                      │
    │  NodePort   : ${var.app1_node_port}                                         │
    │  Interne    : http://hello-app1.${var.namespace}.svc.cluster.local │
    └───────────────────────────────────────────────────────────────┘

    ┌─ App 2 — Thème Cosmos 🚀 ───────────────────────────────────┐
    │  Deployment : hello-app2                                      │
    │  NodePort   : ${var.app2_node_port}                                         │
    │  Interne    : http://hello-app2.${var.namespace}.svc.cluster.local │
    └───────────────────────────────────────────────────────────────┘

    ┌─ Cloudflare Tunnel ☁️ ───────────────────────────────────────┐
    │  Deployment : cloudflared (x2 replicas)                       │
    │  Tunnel     : dc-kube                                         │
    │  Config     : Zero Trust > Networks > Tunnels > dc-kube       │
    │               > Public Hostnames                              │
    │  Cibles DNS :                                                 │
    │    → http://hello-app1.${var.namespace}.svc.cluster.local:80  │
    │    → http://hello-app2.${var.namespace}.svc.cluster.local:80  │
    └───────────────────────────────────────────────────────────────┘

    Commandes utiles :
      # Statut des pods
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} get pods

      # Logs cloudflared
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} logs -l app=cloudflared

  EOT
}
