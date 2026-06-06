output "perso_info" {
  value = module.perso.perso_info
}

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
    ║          hello-world — Déploiements Kubernetes (nginx)         ║
    ╚════════════════════════════════════════════════════════════════╝
  EOT
}
