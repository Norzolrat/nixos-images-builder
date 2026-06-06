# ════════════════════════════════════════════════════════════════
#  Module perso — tf-mono
#  Passbolt · Affine · NextExplorer · Ghostfolio
#
#  Services accessibles sur le VLAN perso via externalIPs :
#    Passbolt     → http://<perso_vlan_ip>:8080
#    Affine       → http://<perso_vlan_ip>:3010
#    NextExplorer → http://<perso_vlan_ip>:8085
#    Ghostfolio   → http://<perso_vlan_ip>:3333
#
#  Infrastructure interne (ClusterIP uniquement) :
#    PostgreSQL → Affine + Ghostfolio + Passbolt
#    Redis      → Affine + Ghostfolio
# ════════════════════════════════════════════════════════════════

# ── Namespace ────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "perso"
      environment = "perso"
    }
  }
  timeouts { delete = "15m" }
}

# ════════════════════════════════════════════════════════════════
#  POSTGRESQL 
# ════════════════════════════════════════════════════════════════

resource "kubernetes_config_map_v1" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "postgres", managed-by = "terraform" }
  }

  data = {
    "init.sql" = <<-SQL
      CREATE DATABASE affine;
      CREATE DATABASE ghostfolio;
      CREATE DATABASE passbolt;
    SQL
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  wait_for_rollout = false

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "postgres", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "postgres" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "postgres" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "postgres"
          image = var.postgres_image

          env {
            name  = "POSTGRES_PASSWORD"
            value = var.postgres_password
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { memory = "512Mi" }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
          volume_mount {
            name       = "init"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }

        volume {
          name = "data"
          host_path {
            path = "${var.host_data_path}/postgres"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "init"
          config_map {
            name = kubernetes_config_map_v1.postgres_init.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "postgres", managed-by = "terraform" }
  }
  spec {
    selector = { app = "postgres" }
    type     = "ClusterIP"
    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  REDIS
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "redis" {
  wait_for_rollout = false

  metadata {
    name      = "redis"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "redis", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "redis" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "redis" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "redis"
          image = var.redis_image

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { memory = "256Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "redis", managed-by = "terraform" }
  }
  spec {
    selector = { app = "redis" }
    type     = "ClusterIP"
    port {
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  PASSBOLT — GPG Keys Secret
# ════════════════════════════════════════════════════════════════

resource "kubernetes_secret_v1" "passbolt_gpg" {
  metadata {
    name      = "passbolt-gpg"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "passbolt", managed-by = "terraform" }
  }

  data = {
    "serverkey.asc"         = var.passbolt_gpg_public_key
    "serverkey_private.asc" = var.passbolt_gpg_private_key
  }
}

# ════════════════════════════════════════════════════════════════
#  PASSBOLT — Gestionnaire de mots de passe  🔑  :8080
#
#  Procédure 1er démarrage :
#    1. Laisser passbolt_gpg_fingerprint vide et déployer
#    2. kubectl logs -n perso deploy/passbolt | grep -i fingerprint
#    3. Renseigner perso_passbolt_gpg_fingerprint dans tfvars + re-apply
#    4. kubectl exec -n perso deploy/passbolt -- su -s /bin/bash www-data \
#         -c "./bin/cake passbolt register_user -u admin@example.com \
#         -f Admin -l User -r admin"
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "passbolt" {
  wait_for_rollout = false

  metadata {
    name      = "passbolt"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "passbolt", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "passbolt" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "passbolt" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        init_container {
          name    = "fix-perms"
          image   = "busybox:latest"
          command = ["sh", "-c", "chmod -R 777 /etc/passbolt/jwt"]

          volume_mount {
            name       = "jwt"
            mount_path = "/etc/passbolt/jwt"
          }
        }

        container {
          name  = "passbolt"
          image = var.passbolt_image

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          env {
            name  = "DATASOURCES_DEFAULT_DRIVER"
            value = "Cake\\Database\\Driver\\Postgres"
          }
          env {
            name  = "DATASOURCES_DEFAULT_HOST"
            value = "postgres.${var.namespace}.svc.cluster.local"
          }
          env {
            name  = "DATASOURCES_DEFAULT_PORT"
            value = "5432"
          }
          env {
            name  = "DATASOURCES_DEFAULT_USERNAME"
            value = "postgres"
          }
          env {
            name  = "DATASOURCES_DEFAULT_PASSWORD"
            value = var.postgres_password
          }
          env {
            name  = "DATASOURCES_DEFAULT_DATABASE"
            value = "passbolt"
          }
          env {
            name  = "DATASOURCES_DEFAULT_ENCODING"
            value = "utf8"
          }
          env {
            name  = "APP_FULL_BASE_URL"
            value = var.passbolt_app_url
          }
          env {
            name  = "PASSBOLT_REGISTRATION_PUBLIC"
            value = "true"
          }
          env {
            name  = "PASSBOLT_GPG_SERVER_KEY_FINGERPRINT"
            value = var.passbolt_gpg_fingerprint
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { memory = "512Mi" }
          }

          volume_mount {
            name       = "gpg"
            mount_path = "/etc/passbolt/gpg"
          }
          volume_mount {
            name       = "jwt"
            mount_path = "/etc/passbolt/jwt"
          }
        }

        volume {
          name = "gpg"
          secret {
            secret_name  = kubernetes_secret_v1.passbolt_gpg.metadata[0].name
            default_mode = "0444"
          }
        }
        volume {
          name = "jwt"
          host_path {
            path = "${var.host_data_path}/passbolt/jwt"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.postgres, kubernetes_secret_v1.passbolt_gpg]
}

resource "kubernetes_service_v1" "passbolt" {
  metadata {
    name      = "passbolt"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "passbolt", managed-by = "terraform" }
  }
  spec {
    selector     = { app = "passbolt" }
    type         = "ClusterIP"
    external_ips = [var.perso_vlan_ip]
    port {
      name        = "http"
      port        = 8080
      target_port = 80
      protocol    = "TCP"
    }
    port {
      name        = "https"
      port        = 8443
      target_port = 443
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  AFFINE — Espace de travail collaboratif  📝  :3010
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "affine" {
  wait_for_rollout = false

  metadata {
    name      = "affine"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "affine", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "affine" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "affine" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        init_container {
          name    = "affine-migration"
          image   = var.affine_image
          command = ["sh", "-c", "node ./scripts/self-host-predeploy.js"]

          env {
            name  = "DATABASE_URL"
            value = "postgresql://postgres:${var.postgres_password}@postgres.${var.namespace}.svc.cluster.local:5432/affine"
          }
          env {
            name  = "REDIS_SERVER_HOST"
            value = "redis.${var.namespace}.svc.cluster.local"
          }
          env {
            name  = "AFFINE_INDEXER_ENABLED"
            value = "false"
          }

          volume_mount {
            name       = "storage"
            mount_path = "/root/.affine/storage"
          }
          volume_mount {
            name       = "config"
            mount_path = "/root/.affine/config"
          }
        }

        container {
          name  = "affine"
          image = var.affine_image

          port {
            name           = "http"
            container_port = 3010
            protocol       = "TCP"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }
          env {
            name  = "DATABASE_URL"
            value = "postgresql://postgres:${var.postgres_password}@postgres.${var.namespace}.svc.cluster.local:5432/affine"
          }
          env {
            name  = "REDIS_SERVER_HOST"
            value = "redis.${var.namespace}.svc.cluster.local"
          }
          env {
            name  = "REDIS_SERVER_PORT"
            value = "6379"
          }
          env {
            name  = "AFFINE_INDEXER_ENABLED"
            value = "false"
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { memory = "1Gi" }
          }

          volume_mount {
            name       = "storage"
            mount_path = "/root/.affine/storage"
          }
          volume_mount {
            name       = "config"
            mount_path = "/root/.affine/config"
          }
        }

        volume {
          name = "storage"
          host_path {
            path = "${var.host_data_path}/affine/storage"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "config"
          host_path {
            path = "${var.host_data_path}/affine/config"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.postgres, kubernetes_deployment_v1.redis]
}

resource "kubernetes_service_v1" "affine" {
  metadata {
    name      = "affine"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "affine", managed-by = "terraform" }
  }
  spec {
    selector     = { app = "affine" }
    type         = "ClusterIP"
    external_ips = [var.perso_vlan_ip]
    port {
      name        = "http"
      port        = 3010
      target_port = 3010
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  GHOSTFOLIO — Suivi de portefeuille  📈  :3333
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "ghostfolio" {
  wait_for_rollout = false

  metadata {
    name      = "ghostfolio"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "ghostfolio", managed-by = "terraform" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "ghostfolio" } }
    strategy { type = "Recreate" }

    template {
      metadata { labels = { app = "ghostfolio" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "ghostfolio"
          image = var.ghostfolio_image

          port {
            name           = "http"
            container_port = 3333
            protocol       = "TCP"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }
          env {
            name  = "DATABASE_URL"
            value = "postgresql://postgres:${var.postgres_password}@postgres.${var.namespace}.svc.cluster.local:5432/ghostfolio?sslmode=disable"
          }
          env {
            name  = "REDIS_HOST"
            value = "redis.${var.namespace}.svc.cluster.local"
          }
          env {
            name  = "REDIS_PORT"
            value = "6379"
          }
          env {
            name  = "ACCESS_TOKEN_SALT"
            value = var.ghostfolio_secret
          }
          env {
            name  = "JWT_SECRET_KEY"
            value = var.ghostfolio_secret
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { memory = "512Mi" }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.postgres, kubernetes_deployment_v1.redis]
}

resource "kubernetes_service_v1" "ghostfolio" {
  metadata {
    name      = "ghostfolio"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "ghostfolio", managed-by = "terraform" }
  }
  spec {
    selector     = { app = "ghostfolio" }
    type         = "ClusterIP"
    external_ips = [var.perso_vlan_ip]
    port {
      name        = "http"
      port        = 3333
      target_port = 3333
      protocol    = "TCP"
    }
  }
}
