resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "cloudflare"
      environment = "dmz"
    }
  }
  timeouts { delete = "15m" }
}

resource "kubernetes_secret_v1" "tunnel_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "cloudflared"
      managed-by = "terraform"
    }
  }

  data = {
    token = var.tunnel_token
  }

  type = "Opaque"
}

resource "kubernetes_deployment_v1" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "cloudflared"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "cloudflared" }
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
        labels = { app = "cloudflared" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "cloudflared"
          image = var.image

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
                name = kubernetes_secret_v1.tunnel_token.metadata[0].name
                key  = "token"
              }
            }
          }

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
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}
