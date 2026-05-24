# ════════════════════════════════════════
#  Cloudflare Tunnel — cloudflared
# ════════════════════════════════════════
# Le token se récupère dans :
#   Zero Trust > Networks > Tunnels > dc-kube > Configure > Installer le connecteur
#
# Passer le token via (ne jamais committer) :
#   terraform apply -var="cloudflare_tunnel_token=<token>"
#   ou TF_VAR_cloudflare_tunnel_token=<token> terraform apply
#   ou dans terraform.tfvars (fichier .gitignored)
# ════════════════════════════════════════

# ----------------------------------------
# Secret Kubernetes — token du tunnel
# ----------------------------------------

resource "kubernetes_secret_v1" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "cloudflared"
      managed-by = "terraform"
    }
  }

  data = {
    token = var.cloudflare_tunnel_token
  }

  type = "Opaque"
}

# ----------------------------------------
# Deployment — cloudflared
# ----------------------------------------

resource "kubernetes_deployment_v1" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "cloudflared"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        # Kubernetes substitue $(TUNNEL_TOKEN) depuis les env vars du container
        container {
          name  = "cloudflared"
          image = var.cloudflared_image

          # https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/
          args = [
            "tunnel",
            "--no-autoupdate",
            "--metrics", "0.0.0.0:2000",
            "run",
            "--token", "$(TUNNEL_TOKEN)",
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.cloudflared_token.metadata[0].name
                key  = "token"
              }
            }
          }

          # Vérifier que le tunnel est prêt à recevoir du trafic
          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}
