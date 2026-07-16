# ════════════════════════════════════════════════════════════════
#  Traefik — Reverse proxy VLAN dmz
#  Config statique : config/traefik.toml
#  Config dynamique : config/dynamic/*.toml
#  Certs : Let's Encrypt via DNS challenge Cloudflare (acme.json)
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

# ── Secrets ──────────────────────────────────────────────────────

resource "kubernetes_secret_v1" "dashboard_auth" {
  metadata {
    name      = "traefik-dashboard-auth"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
  }
  data = {
    users = var.dashboard_htpasswd
  }
}

resource "kubernetes_secret_v1" "cloudflare" {
  metadata {
    name      = "traefik-cloudflare"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
  }

  data = {
    CF_DNS_API_TOKEN = var.cloudflare_api_token
  }
}

# ── ConfigMaps ───────────────────────────────────────────────────

resource "kubernetes_config_map_v1" "traefik_static" {
  metadata {
    name      = "traefik-static"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
  }

  data = {
    "traefik.toml" = file("${path.module}/config/traefik.toml")
  }
}

resource "kubernetes_config_map_v1" "traefik_dynamic" {
  metadata {
    name      = "traefik-dynamic"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
  }

  data = {
    "bastion.toml"   = file("${path.module}/config/dynamic/bastion.toml")
    "certs.toml"     = file("${path.module}/config/dynamic/certs.toml")
    "coder.toml"     = file("${path.module}/config/dynamic/coder.toml")
    "midlwares.toml" = file("${path.module}/config/dynamic/midlwares.toml")
    "proxy.toml"     = file("${path.module}/config/dynamic/proxy.toml")
    "teleport.toml"  = file("${path.module}/config/dynamic/teleport.toml")
  }
}

# ── Deployment ───────────────────────────────────────────────────

resource "kubernetes_deployment_v1" "traefik" {
  wait_for_rollout = false

  metadata {
    name      = "traefik"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "traefik" } }

    template {
      metadata { labels = { app = "traefik" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "traefik"
          image = var.image

          args = ["--configfile=/etc/traefik/traefik.toml"]

          security_context {
            capabilities {
              add = ["NET_BIND_SERVICE"]
            }
          }

          # Token Cloudflare injecté comme variable d'environnement pour ACME
          env_from {
            secret_ref { name = kubernetes_secret_v1.cloudflare.metadata[0].name }
          }

          port {
            name           = "http"
            container_port = 80
          }
          port {
            name           = "https"
            container_port = 443
          }
          port {
            name           = "dashboard"
            container_port = 8080
          }
          port {
            name           = "teleport-ssh"
            container_port = 3023
          }
          port {
            name           = "teleport-tunnel"
            container_port = 3024
          }
          port {
            name           = "teleport-kube"
            container_port = 3026
          }

          volume_mount {
            name       = "static-config"
            mount_path = "/etc/traefik/traefik.toml"
            sub_path   = "traefik.toml"
            read_only  = true
          }

          volume_mount {
            name       = "dynamic-config"
            mount_path = "/etc/traefik/dynamic"
            read_only  = true
          }

          volume_mount {
            name       = "acme"
            mount_path = "/etc/traefik/acme"
          }

          volume_mount {
            name       = "logs"
            mount_path = "/var/log/traefik"
          }

          volume_mount {
            name       = "dashboard-auth"
            mount_path = "/etc/traefik/auth"
            read_only  = true
          }
        }

        volume {
          name = "static-config"
          config_map { name = kubernetes_config_map_v1.traefik_static.metadata[0].name }
        }

        volume {
          name = "dynamic-config"
          config_map { name = kubernetes_config_map_v1.traefik_dynamic.metadata[0].name }
        }

        volume {
          name = "acme"
          host_path {
            path = var.acme_host_data_path
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "logs"
          empty_dir {}
        }

        volume {
          name = "dashboard-auth"
          secret { secret_name = kubernetes_secret_v1.dashboard_auth.metadata[0].name }
        }
      }
    }
  }
}

# ── Service ──────────────────────────────────────────────────────

resource "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "traefik", managed-by = "terraform" }
    annotations = {
      # MetalLB L2 : IP fixe depuis le pool "dmz"
      "metallb.universe.tf/loadBalancerIPs" = var.dmz_vlan_ip
    }
  }

  spec {
    type         = "LoadBalancer"
    selector     = { app = "traefik" }
    external_ips = [var.mgmt_ip]  # accès mgmt pour le NAT SNS

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }

    port {
      name        = "dashboard"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    port {
      name        = "teleport-ssh"
      port        = 3023
      target_port = 3023
      protocol    = "TCP"
    }

    port {
      name        = "teleport-tunnel"
      port        = 3024
      target_port = 3024
      protocol    = "TCP"
    }

    port {
      name        = "teleport-kube"
      port        = 3026
      target_port = 3026
      protocol    = "TCP"
    }
  }
}
