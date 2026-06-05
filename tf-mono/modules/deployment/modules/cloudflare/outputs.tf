output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "info" {
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║              Cloudflare Tunnel — VLAN dmz                     ║
    ╚════════════════════════════════════════════════════════════════╝

    Namespace : ${kubernetes_namespace_v1.this.metadata[0].name}
    Replicas  : ${var.replicas}

    Config Zero Trust → ajouter les Public Hostnames :
      → http://traefik.traefik.svc.cluster.local:80

    Logs :
      kubectl -n ${kubernetes_namespace_v1.this.metadata[0].name} logs -l app=cloudflared -f

  EOT
}
