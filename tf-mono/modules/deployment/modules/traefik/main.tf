# ════════════════════════════════════════════════════════════════
#  Traefik — Reverse proxy VLAN dmz
#  TODO : la configuration sera ajoutée ultérieurement
# ════════════════════════════════════════════════════════════════

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "traefik"
      environment = "dmz"
    }
  }
  timeouts { delete = "15m" }
}

# Les ressources Traefik (Deployment, Service, ConfigMap, IngressRoute...)
# seront ajoutées ici une fois la configuration fournie.
