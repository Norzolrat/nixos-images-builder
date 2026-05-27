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

    ┌─ GPU Test AMD 🎮 ───────────────────────────────────────────┐
    │  Job        : ${module.kube_gpu.job_name}
    │  Image      : ${module.kube_gpu.image}
    │  Node label : ${module.kube_gpu.node_selector}                         │
    │  Ressource  : amd.com/gpu = 1                                 │
    └───────────────────────────────────────────────────────────────┘

    Commandes utiles :
      # Statut des pods
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} get pods

      # Logs cloudflared
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} logs -l app=cloudflared

      # ── GPU Test (module kube-gpu) ────────────────────────────
      # 1) Labelliser le node GPU (à faire UNE SEULE FOIS) :
      #    kubectl --kubeconfig ../export/kubeconfig \
      #      label node <nom-du-node-gpu> ${var.gpu_node_label_key}=${var.gpu_node_label_value} --overwrite

      # 2) Statut du Job :
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} get job ${module.kube_gpu.job_name}

      # 3) Logs du test GPU :
      kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} logs -l app=gpu-test --tail=100

      # 4) Relancer le test (supprimer + re-apply) :
      #    kubectl --kubeconfig ../export/kubeconfig -n ${kubernetes_namespace_v1.hello_world.metadata[0].name} delete job ${module.kube_gpu.job_name}
      #    terraform apply -target=module.kube_gpu

  EOT
}

# ── Output GPU Test (délégué au module) ─────────────────────────

output "gpu_test_info" {
  description = "Informations sur le Job de test GPU AMD (module kube-gpu)"
  value       = module.kube_gpu.gpu_test_commands
}

