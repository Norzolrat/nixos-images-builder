# ════════════════════════════════════════════════════════════════
#  Module llm-stack — Outputs
# ════════════════════════════════════════════════════════════════

output "namespace" {
  description = "Namespace Kubernetes de la stack LLM"
  value       = kubernetes_namespace_v1.llm.metadata[0].name
}

output "ollama_service_name" {
  value = kubernetes_service_v1.ollama.metadata[0].name
}

output "ollama_cluster_url" {
  description = "URL interne Ollama (depuis les autres pods du cluster)"
  value       = "http://ollama.${var.namespace}.svc.cluster.local:11434"
}

output "comfyui_cluster_url" {
  description = "URL interne ComfyUI"
  value       = "http://comfyui.${var.namespace}.svc.cluster.local:8188"
}

output "searxng_cluster_url" {
  description = "URL interne SearXNG"
  value       = "http://searxng.${var.namespace}.svc.cluster.local:8080"
}

output "node_ports" {
  description = "NodePorts exposés pour chaque service actif"
  value = merge(
    {
      ollama     = var.ollama_node_port
      open_webui = var.open_webui_node_port
    },
    var.enable_comfyui ? { comfyui = var.comfyui_node_port } : {},
    var.enable_searxng ? { searxng = var.searxng_node_port } : {},
  )
}

output "stack_info" {
  description = "Résumé de la stack LLM et URLs d'accès"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║        LLM Stack — Ollama · ComfyUI · Open-WebUI · SearXNG     ║
    ╚══════════════════════════════════════════════════════════════════╝

    Namespace  : ${kubernetes_namespace_v1.llm.metadata[0].name}
    Node GPU   : ${var.gpu_node_label_key}=${var.gpu_node_label_value}
    Data path  : ${var.host_data_path}/ (sur le node GPU)

    ┌─ 🦙 Ollama ──────────────────────────────────────────────────┐
    │  NodePort  : ${var.ollama_node_port}                                           │
    │  Interne   : http://ollama.${var.namespace}.svc.cluster.local:11434   │
    │  Test      : curl http://<node-ip>:${var.ollama_node_port}/api/tags         │
    └──────────────────────────────────────────────────────────────┘

    ┌─ 🎨 ComfyUI ─────────────────────────────────────────────────┐
    │  NodePort  : ${var.comfyui_node_port}                                           │
    │  Interne   : http://comfyui.${var.namespace}.svc.cluster.local:8188    │
    └──────────────────────────────────────────────────────────────┘

    ┌─ 🌐 Open-WebUI ──────────────────────────────────────────────┐
    │  NodePort  : ${var.open_webui_node_port}                                           │
    │  Interne   : http://open-webui.${var.namespace}.svc.cluster.local:8080 │
    └──────────────────────────────────────────────────────────────┘

    ┌─ 🔍 SearXNG ─────────────────────────────────────────────────┐
    │  NodePort  : ${var.searxng_node_port}                                           │
    │  Interne   : http://searxng.${var.namespace}.svc.cluster.local:8080    │
    └──────────────────────────────────────────────────────────────┘

    Commandes utiles :
      # Statut des pods
      kubectl -n ${kubernetes_namespace_v1.llm.metadata[0].name} get pods -o wide

      # Logs Ollama
      kubectl -n ${kubernetes_namespace_v1.llm.metadata[0].name} logs -l app=ollama -f

      # Logs ComfyUI
      kubectl -n ${kubernetes_namespace_v1.llm.metadata[0].name} logs -l app=comfyui -f

      # Télécharger un modèle Ollama
      kubectl -n ${kubernetes_namespace_v1.llm.metadata[0].name} exec -it deploy/ollama -- \
        ollama pull llama3.2

      # Cloudflare Tunnel → ajouter dans Zero Trust > dc-kube > Public Hostnames :
      #   ollama.ton-domaine.com    → http://ollama.${var.namespace}.svc.cluster.local:11434
      #   comfyui.ton-domaine.com   → http://comfyui.${var.namespace}.svc.cluster.local:8188
      #   chat.ton-domaine.com      → http://open-webui.${var.namespace}.svc.cluster.local:8080
      #   search.ton-domaine.com    → http://searxng.${var.namespace}.svc.cluster.local:8080

  EOT
}
