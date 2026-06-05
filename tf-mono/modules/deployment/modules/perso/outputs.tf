output "perso_info" {
  description = "Résumé de la stack perso et URLs d'accès"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║  Perso Stack — Passbolt · Affine · NextExplorer · Ghostfolio   ║
    ╚══════════════════════════════════════════════════════════════════╝

    Namespace  : ${kubernetes_namespace_v1.this.metadata[0].name}
    VLAN perso : ${var.perso_vlan_ip}
    Data       : ${var.host_data_path}/ (hostPath sur le master)

    ┌─ 🔑 Passbolt ─────────────────────────────────────────────────┐
    │  http://${var.perso_vlan_ip}:8080                                   │
    │  1er démarrage :                                               │
    │    kubectl logs -n perso deploy/passbolt | grep -i fingerprint │
    │    → mettre à jour perso_passbolt_gpg_fingerprint + re-apply   │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 📝 Affine ───────────────────────────────────────────────────┐
    │  http://${var.perso_vlan_ip}:3010                                   │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 📁 NextExplorer ─────────────────────────────────────────────┐
    │  http://${var.perso_vlan_ip}:8085                                   │
    │  Login par défaut : admin / admin                              │
    └───────────────────────────────────────────────────────────────┘

    ┌─ 📈 Ghostfolio ───────────────────────────────────────────────┐
    │  http://${var.perso_vlan_ip}:3333                                   │
    └───────────────────────────────────────────────────────────────┘

  EOT
}
