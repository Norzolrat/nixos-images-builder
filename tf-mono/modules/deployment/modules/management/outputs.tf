output "info" {
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║         Management — Loki · Promtail · Teleport · Coder        ║
    ╚════════════════════════════════════════════════════════════════╝
    Loki API      → http://loki.management.svc.cluster.local:3100
    Loki (local)  → kubectl port-forward -n management svc/loki 3100:3100
    Teleport Web  → https://teleport.magnaloca.com
    Teleport SSH  → bastion.magnaloca.com:3023
    Teleport Kube → bastion.magnaloca.com:3026
    Coder         → https://coder.magnaloca.com

    Teleport — premier admin :
      kubectl -n management exec -it deploy/teleport -- \
        tctl users add admin --roles=editor,access,auditor

    Coder — migration DB depuis l'ancienne instance :
      pg_dump postgresql://coder:xxx@10.255.255.25:5432/coder | \
        kubectl -n management exec -i deploy/coder-postgres -- \
          psql -U coder -d coder
  EOT
}
