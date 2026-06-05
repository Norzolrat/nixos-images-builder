output "cloudflare_info" {
  value = module.cloudflare.info
}

output "llm_stack_info" {
  value = module.llm_stack.stack_info
}

output "deployment_info" {
  description = "Résumé des déploiements hello-world"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║          hello-world — Déploiements Kubernetes (nginx)        ║
    ╚════════════════════════════════════════════════════════════════╝

    ┌─ Mario 🍄 ─────────────────────────────────────────────────────┐
    │  Namespace : hello-mario                                        │
    │  URL       : http://${var.mario_external_ip}                        │
    └────────────────────────────────────────────────────────────────┘

    ┌─ Star Wars ⚔️ ─────────────────────────────────────────────────┐
    │  Namespace : hello-starwars                                     │
    │  URL       : http://${var.starwars_external_ip}                     │
    └────────────────────────────────────────────────────────────────┘

    ┌─ Matrix 💊 ────────────────────────────────────────────────────┐
    │  Namespace : hello-matrix                                       │
    │  URL       : http://${var.matrix_external_ip}                       │
    └────────────────────────────────────────────────────────────────┘

  EOT
}
