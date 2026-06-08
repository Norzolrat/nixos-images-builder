# ════════════════════════════════════════════════════════════════
#  Management — Loki · Promtail · Teleport · Coder
#
#  Loki     → http://loki.management.svc.cluster.local:3100
#  Promtail → DaemonSet, collecte pods + journald → Loki
#
#  Teleport — config/teleport.yaml
#    Ports sur var.teleport_vlan_ip :
#      3080 → web UI (HTTPS, via Traefik/Cloudflare)
#      3023 → SSH proxy  (TCP passthrough Traefik bastion.toml)
#      3024 → tunnel     (TCP passthrough Traefik bastion.toml)
#      3026 → kube proxy (TCP passthrough Traefik bastion.toml)
#    Premier démarrage :
#      kubectl -n management exec -it deploy/teleport -- \
#        tctl users add admin --roles=editor,access,auditor
#
#  Coder — PostgreSQL interne + serveur Coder
#    Accessible via Traefik : https://coder.magnaloca.com
#    Migration depuis l'ancienne instance :
#      pg_dump postgresql://coder:xxx@10.255.255.25:5432/coder | \
#        kubectl -n management exec -i deploy/coder-postgres -- \
#          psql -U coder -d coder
# ════════════════════════════════════════════════════════════════

# ── Namespace ────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "management"
      environment = "mgmt"
    }
  }
  timeouts { delete = "15m" }
}

# ════════════════════════════════════════════════════════════════
#  LOKI — Agrégation des logs
# ════════════════════════════════════════════════════════════════

resource "kubernetes_config_map_v1" "loki_config" {
  metadata {
    name      = "loki-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "loki", managed-by = "terraform" }
  }
  data = {
    "loki.yaml" = file("${path.module}/config/loki.yaml")
  }
}

resource "kubernetes_deployment_v1" "loki" {
  wait_for_rollout = false

  metadata {
    name      = "loki"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "loki", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "loki" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "loki" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "loki"
          image = var.loki_image
          args  = ["-config.file=/etc/loki/loki.yaml"]

          port {
            name           = "http"
            container_port = 3100
          }
          port {
            name           = "grpc"
            container_port = 9096
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 3100
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/loki/loki.yaml"
            sub_path   = "loki.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/loki"
          }
        }

        volume {
          name = "config"
          config_map { name = kubernetes_config_map_v1.loki_config.metadata[0].name }
        }

        volume {
          name = "data"
          host_path {
            path = var.loki_host_data_path
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "loki", managed-by = "terraform" }
  }

  spec {
    selector = { app = "loki" }
    port {
      name        = "http"
      port        = 3100
      target_port = 3100
    }
    port {
      name        = "grpc"
      port        = 9096
      target_port = 9096
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  PROMTAIL — Collecte des logs pods + journald
# ════════════════════════════════════════════════════════════════

resource "kubernetes_service_account_v1" "promtail" {
  metadata {
    name      = "promtail"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "promtail", managed-by = "terraform" }
  }
}

resource "kubernetes_cluster_role_v1" "promtail" {
  metadata {
    name   = "promtail-management"
    labels = { app = "promtail", managed-by = "terraform" }
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "promtail" {
  metadata {
    name   = "promtail-management"
    labels = { app = "promtail", managed-by = "terraform" }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.promtail.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.promtail.metadata[0].name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "promtail_config" {
  metadata {
    name      = "promtail-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "promtail", managed-by = "terraform" }
  }
  data = {
    "promtail.yaml" = file("${path.module}/config/promtail.yaml")
  }
}

resource "kubernetes_daemon_set_v1" "promtail" {
  metadata {
    name      = "promtail"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "promtail", managed-by = "terraform" }
  }

  spec {
    selector { match_labels = { app = "promtail" } }

    template {
      metadata { labels = { app = "promtail" } }

      spec {
        service_account_name = kubernetes_service_account_v1.promtail.metadata[0].name

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "promtail"
          image = var.promtail_image
          args  = ["-config.file=/etc/promtail/promtail.yaml"]

          port {
            name           = "http"
            container_port = 9080
          }

          security_context {
            run_as_user = 0
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities { drop = ["ALL"] }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/promtail/promtail.yaml"
            sub_path   = "promtail.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "pods-logs"
            mount_path = "/var/log/pods"
            read_only  = true
          }

          volume_mount {
            name       = "journal"
            mount_path = "/var/log/journal"
            read_only  = true
          }

          volume_mount {
            name       = "machine-id"
            mount_path = "/etc/machine-id"
            read_only  = true
          }

          volume_mount {
            name       = "run-promtail"
            mount_path = "/run/promtail"
          }
        }

        volume {
          name = "config"
          config_map { name = kubernetes_config_map_v1.promtail_config.metadata[0].name }
        }

        volume {
          name = "pods-logs"
          host_path { path = "/var/log/pods" }
        }

        volume {
          name = "journal"
          host_path { path = "/var/log/journal" }
        }

        volume {
          name = "machine-id"
          host_path { path = "/etc/machine-id" }
        }

        volume {
          name = "run-promtail"
          empty_dir {}
        }
      }
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  TELEPORT
# ════════════════════════════════════════════════════════════════

# ── RBAC — service account in-cluster pour kubernetes_service ───

resource "kubernetes_service_account_v1" "teleport" {
  metadata {
    name      = "teleport"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "teleport", managed-by = "terraform" }
  }
}

resource "kubernetes_cluster_role_v1" "teleport" {
  metadata {
    name   = "teleport-management"
    labels = { app = "teleport", managed-by = "terraform" }
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/exec", "services", "endpoints", "namespaces", "nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectaccessreviews", "selfsubjectrulesreviews"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "teleport" {
  metadata {
    name   = "teleport-management"
    labels = { app = "teleport", managed-by = "terraform" }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.teleport.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.teleport.metadata[0].name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

# ── ConfigMap ────────────────────────────────────────────────────

resource "kubernetes_config_map_v1" "teleport_config" {
  metadata {
    name      = "teleport-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "teleport", managed-by = "terraform" }
  }

  data = {
    "teleport.yaml" = file("${path.module}/config/teleport.yaml")
  }
}

# ── Deployment ───────────────────────────────────────────────────

resource "kubernetes_deployment_v1" "teleport" {
  wait_for_rollout = false

  metadata {
    name      = "teleport"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "teleport", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "teleport" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "teleport" } }

      spec {
        service_account_name = kubernetes_service_account_v1.teleport.metadata[0].name

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "teleport"
          image = var.teleport_image

          args = ["--config=/etc/teleport/teleport.yaml"]

          port {
            name           = "web"
            container_port = 3080
            protocol       = "TCP"
          }
          port {
            name           = "ssh"
            container_port = 3023
            protocol       = "TCP"
          }
          port {
            name           = "tunnel"
            container_port = 3024
            protocol       = "TCP"
          }
          port {
            name           = "kube"
            container_port = 3026
            protocol       = "TCP"
          }
          port {
            name           = "auth"
            container_port = 3025
            protocol       = "TCP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/teleport/teleport.yaml"
            sub_path   = "teleport.yaml"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/teleport"
          }
        }

        volume {
          name = "config"
          config_map { name = kubernetes_config_map_v1.teleport_config.metadata[0].name }
        }

        volume {
          name = "data"
          host_path {
            path = var.teleport_host_data_path
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

# ── Service ──────────────────────────────────────────────────────

resource "kubernetes_service_v1" "teleport" {
  metadata {
    name      = "teleport"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "teleport", managed-by = "terraform" }
  }

  spec {
    selector     = { app = "teleport" }
    external_ips = [var.teleport_vlan_ip]

    port {
      name        = "web"
      port        = 3080
      target_port = 3080
      protocol    = "TCP"
    }
    port {
      name        = "ssh"
      port        = 3023
      target_port = 3023
      protocol    = "TCP"
    }
    port {
      name        = "tunnel"
      port        = 3024
      target_port = 3024
      protocol    = "TCP"
    }
    port {
      name        = "kube"
      port        = 3026
      target_port = 3026
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  CODER — PostgreSQL
# ════════════════════════════════════════════════════════════════

resource "kubernetes_secret_v1" "coder_postgres" {
  metadata {
    name      = "coder-postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder-postgres", managed-by = "terraform" }
  }

  data = {
    POSTGRES_DB       = "coder"
    POSTGRES_USER     = "coder"
    POSTGRES_PASSWORD = var.coder_postgres_password
  }
}

resource "kubernetes_deployment_v1" "coder_postgres" {
  wait_for_rollout = false

  metadata {
    name      = "coder-postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder-postgres", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "coder-postgres" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "coder-postgres" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "postgres"
          image = "postgres:16"

          port { container_port = 5432 }

          env_from {
            secret_ref { name = kubernetes_secret_v1.coder_postgres.metadata[0].name }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "data"
          host_path {
            path = var.coder_host_data_path
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "coder_postgres" {
  metadata {
    name      = "coder-postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder-postgres", managed-by = "terraform" }
  }

  spec {
    selector = { app = "coder-postgres" }
    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  CODER — Serveur
# ════════════════════════════════════════════════════════════════

resource "kubernetes_secret_v1" "coder" {
  metadata {
    name      = "coder"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder", managed-by = "terraform" }
  }

  data = {
    CODER_PG_CONNECTION_URL = "postgresql://coder:${var.coder_postgres_password}@coder-postgres.${var.namespace}.svc.cluster.local:5432/coder?sslmode=disable"
  }
}

resource "kubernetes_deployment_v1" "coder" {
  wait_for_rollout = false

  metadata {
    name      = "coder"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "coder" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "coder" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "coder"
          image = var.coder_image

          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }

          env_from {
            secret_ref { name = kubernetes_secret_v1.coder.metadata[0].name }
          }

          env {
            name  = "CODER_HTTP_ADDRESS"
            value = "0.0.0.0:3000"
          }
          env {
            name  = "CODER_TLS_ENABLE"
            value = "false"
          }
          env {
            name  = "CODER_ACCESS_URL"
            value = var.coder_access_url
          }
          env {
            name  = "CODER_WILDCARD_ACCESS_URL"
            value = var.coder_wildcard_access_url
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "coder" {
  metadata {
    name      = "coder"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "coder", managed-by = "terraform" }
  }

  spec {
    selector = { app = "coder" }
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }
  }
}
