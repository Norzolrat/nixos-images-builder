resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by = "terraform"
      theme      = "hello-world"
    }
  }
  timeouts { delete = "15m" }
}

# ── Config nginx avec sélection aléatoire par requête ────────────

resource "kubernetes_config_map_v1" "nginx_config" {
  metadata {
    name      = "hello-nginx-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "default.conf" = <<-NGINX
      split_clients "$request_id" $theme_dir {
          33%   "mario";
          34%   "starwars";
          *     "matrix";
      }

      server {
          listen 80;
          location / {
              root /usr/share/nginx/html;
              try_files /$theme_dir/index.html =404;
          }
      }
    NGINX
  }
}

# ── ConfigMaps HTML ───────────────────────────────────────────────

resource "kubernetes_config_map_v1" "mario" {
  metadata {
    name      = "mario-html"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = { "index.html" = file("${path.module}/src/mario.html") }
}

resource "kubernetes_config_map_v1" "matrix" {
  metadata {
    name      = "matrix-html"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = { "index.html" = file("${path.module}/src/matrix.html") }
}

resource "kubernetes_config_map_v1" "starwars" {
  metadata {
    name      = "starwars-html"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = { "index.html" = file("${path.module}/src/starwars.html") }
}

# ── Deployment unique — nginx choisit le thème par requête ───────

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "hello-world", managed-by = "terraform" }
  }

  spec {
    replicas = var.replicas
    selector { match_labels = { app = "hello-world" } }

    template {
      metadata { labels = { app = "hello-world" } }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "nginx"
          image = var.nginx_image

          port { container_port = 80 }

          resources {
            requests = { cpu = "50m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "64Mi" }
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
            read_only  = true
          }
          volume_mount {
            name       = "mario-html"
            mount_path = "/usr/share/nginx/html/mario"
            read_only  = true
          }
          volume_mount {
            name       = "matrix-html"
            mount_path = "/usr/share/nginx/html/matrix"
            read_only  = true
          }
          volume_mount {
            name       = "starwars-html"
            mount_path = "/usr/share/nginx/html/starwars"
            read_only  = true
          }
        }

        volume {
          name = "nginx-config"
          config_map { name = kubernetes_config_map_v1.nginx_config.metadata[0].name }
        }
        volume {
          name = "mario-html"
          config_map { name = kubernetes_config_map_v1.mario.metadata[0].name }
        }
        volume {
          name = "matrix-html"
          config_map { name = kubernetes_config_map_v1.matrix.metadata[0].name }
        }
        volume {
          name = "starwars-html"
          config_map { name = kubernetes_config_map_v1.starwars.metadata[0].name }
        }
      }
    }
  }
}

# ── Service ───────────────────────────────────────────────────────

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "hello-world", managed-by = "terraform" }
  }

  spec {
    selector     = { app = "hello-world" }
    type         = "ClusterIP"
    external_ips = [var.external_ip]

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}
