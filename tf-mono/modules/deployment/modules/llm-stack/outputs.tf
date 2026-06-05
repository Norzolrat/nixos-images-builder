output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "stack_info" {
  description = "Résumé de la stack LLM et URLs d'accès"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║        LLM Stack — Ollama · Open-WebUI · ComfyUI · SearXNG     ║
    ╚══════════════════════════════════════════════════════════════════╝

    Namespace : ${kubernetes_namespace_v1.this.metadata[0].name}
    VLAN ai   : ${var.ai_vlan_ip}
    Data      : ${var.host_data_path}/ (hostPath sur le master)

    ┌─ 🦙 Ollama API ───────────────────────────────────────────────┐
    │  http://${var.ai_vlan_ip}:11434                                     │
    │  Test : curl http://${var.ai_vlan_ip}:11434/api/tags               │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 🌐 Open-WebUI ───────────────────────────────────────────────┐
    │  http://${var.ai_vlan_ip}:8080                                      │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 🎨 ComfyUI ${var.enable_comfyui ? "(activé)" : "(désactivé)"} ──────────────────────────────────────┐
    │  http://${var.ai_vlan_ip}:8188                                      │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 🔍 SearXNG ${var.enable_searxng ? "(activé)" : "(désactivé)"} ──────────────────────────────────────┐
    │  http://${var.ai_vlan_ip}:8085                                      │
    └───────────────────────────────────────────────────────────────┘

  EOT
}
