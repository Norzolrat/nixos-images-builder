# ========================================
# Namespace
# ========================================

resource "kubernetes_namespace_v1" "hello_world" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      environment = "demo"
    }
  }

  timeouts {
    delete = "15m"
  }
}

# ════════════════════════════════════════
#  APP 1  ——  Thème Océan  🌍
# ════════════════════════════════════════

resource "kubernetes_config_map_v1" "app1_html" {
  metadata {
    name      = "hello-app1-html"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
  }

  data = {
    "index.html" = <<-EOT
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hello World — App 1</title>
        <style>
          *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #0a0e27 0%, #0d2137 45%, #0a3d62 100%);
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            color: #fff;
            overflow: hidden;
          }

          .bg-orb {
            position: fixed;
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.18;
            animation: drift 8s ease-in-out infinite alternate;
          }
          .bg-orb-1 { width: 500px; height: 500px; background: #00b4d8; top: -150px; left: -150px; }
          .bg-orb-2 { width: 400px; height: 400px; background: #0077b6; bottom: -100px; right: -100px; animation-delay: -4s; }

          @keyframes drift { to { transform: translate(30px, 20px) scale(1.05); } }

          .card {
            position: relative;
            background: rgba(255,255,255,0.07);
            border: 1px solid rgba(255,255,255,0.12);
            border-radius: 28px;
            padding: 64px 80px;
            text-align: center;
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            box-shadow:
              0 32px 64px rgba(0,0,0,0.45),
              0 0 0 1px rgba(255,255,255,0.04) inset;
            max-width: 520px;
            width: 90vw;
          }

          .emoji {
            font-size: 80px;
            line-height: 1;
            margin-bottom: 28px;
            display: block;
            animation: float 3s ease-in-out infinite;
          }
          @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50%       { transform: translateY(-10px); }
          }

          h1 {
            font-size: clamp(2rem, 6vw, 3.2rem);
            font-weight: 800;
            letter-spacing: -1.5px;
            background: linear-gradient(90deg, #90e0ef, #caf0f8, #fff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 14px;
          }

          .subtitle {
            color: rgba(255,255,255,0.55);
            font-size: 1.05rem;
            letter-spacing: 0.3px;
          }

          .divider {
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent);
            margin: 28px 0;
          }

          .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 20px;
            background: linear-gradient(90deg, #00b4d8, #0077b6);
            border-radius: 100px;
            font-size: 0.82rem;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            box-shadow: 0 4px 20px rgba(0,180,216,0.35);
          }

          .stack {
            margin-top: 20px;
            display: flex;
            justify-content: center;
            gap: 10px;
            flex-wrap: wrap;
          }
          .tag {
            padding: 4px 12px;
            border-radius: 8px;
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.1);
            font-size: 0.75rem;
            color: rgba(255,255,255,0.6);
          }
        </style>
      </head>
      <body>
        <div class="bg-orb bg-orb-1"></div>
        <div class="bg-orb bg-orb-2"></div>

        <div class="card">
          <span class="emoji">🌍</span>
          <h1>Hello, World!</h1>
          <p class="subtitle">Application 1 &mdash; Déploiement Kubernetes</p>
          <div class="divider"></div>
          <div class="badge">
            <span>🚢</span>
            NixOS &bull; kubeadm &bull; nginx
          </div>
          <div class="stack">
            <span class="tag">namespace: hello-world</span>
            <span class="tag">app: hello-app1</span>
            <span class="tag">✓ running</span>
          </div>
        </div>
      </body>
      </html>
    EOT
  }
}

resource "kubernetes_deployment_v1" "app1" {
  metadata {
    name      = "hello-app1"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "hello-app1"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "hello-app1"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-app1"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = var.nginx_image

          port {
            container_port = 80
            protocol       = "TCP"
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map_v1.app1_html.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app1" {
  metadata {
    name      = "hello-app1"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "hello-app1"
      managed-by = "terraform"
    }
  }

  spec {
    selector = {
      app = "hello-app1"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      node_port   = var.app1_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}


# ════════════════════════════════════════
#  APP 2  ——  Thème Cosmos  🚀
# ════════════════════════════════════════

resource "kubernetes_config_map_v1" "app2_html" {
  metadata {
    name      = "hello-app2-html"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
  }

  data = {
    "index.html" = <<-EOT
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hello World — App 2</title>
        <style>
          *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #0d0010 0%, #1a0033 45%, #300060 100%);
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            color: #fff;
            overflow: hidden;
          }

          .stars {
            position: fixed;
            inset: 0;
            background-image:
              radial-gradient(1px 1px at 20% 30%, rgba(255,255,255,0.8) 0%, transparent 100%),
              radial-gradient(1px 1px at 80% 10%, rgba(255,255,255,0.7) 0%, transparent 100%),
              radial-gradient(1px 1px at 60% 70%, rgba(255,255,255,0.6) 0%, transparent 100%),
              radial-gradient(1px 1px at 10% 80%, rgba(255,255,255,0.5) 0%, transparent 100%),
              radial-gradient(1px 1px at 45% 50%, rgba(255,255,255,0.4) 0%, transparent 100%),
              radial-gradient(2px 2px at 90% 60%, rgba(255,255,255,0.6) 0%, transparent 100%),
              radial-gradient(1px 1px at 35% 15%, rgba(255,255,255,0.9) 0%, transparent 100%),
              radial-gradient(1px 1px at 70% 85%, rgba(255,255,255,0.5) 0%, transparent 100%);
          }

          .bg-orb {
            position: fixed;
            border-radius: 50%;
            filter: blur(90px);
            opacity: 0.15;
            animation: drift 9s ease-in-out infinite alternate;
          }
          .bg-orb-1 { width: 550px; height: 550px; background: #7c3aed; top: -200px; right: -150px; }
          .bg-orb-2 { width: 450px; height: 450px; background: #db2777; bottom: -120px; left: -100px; animation-delay: -5s; }

          @keyframes drift { to { transform: translate(25px, 15px) scale(1.06); } }

          .card {
            position: relative;
            background: rgba(255,255,255,0.06);
            border: 1px solid rgba(200,150,255,0.2);
            border-radius: 28px;
            padding: 64px 80px;
            text-align: center;
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            box-shadow:
              0 32px 64px rgba(80,0,120,0.5),
              0 0 0 1px rgba(255,255,255,0.04) inset;
            max-width: 520px;
            width: 90vw;
          }

          .emoji {
            font-size: 80px;
            line-height: 1;
            margin-bottom: 28px;
            display: block;
            animation: launch 4s ease-in-out infinite;
          }
          @keyframes launch {
            0%, 100% { transform: translateY(0px) rotate(-5deg); }
            50%       { transform: translateY(-12px) rotate(5deg); }
          }

          h1 {
            font-size: clamp(2rem, 6vw, 3.2rem);
            font-weight: 800;
            letter-spacing: -1.5px;
            background: linear-gradient(90deg, #c084fc, #f0abfc, #fff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 14px;
          }

          .subtitle {
            color: rgba(255,255,255,0.55);
            font-size: 1.05rem;
            letter-spacing: 0.3px;
          }

          .divider {
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(200,150,255,0.25), transparent);
            margin: 28px 0;
          }

          .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 20px;
            background: linear-gradient(90deg, #7c3aed, #db2777);
            border-radius: 100px;
            font-size: 0.82rem;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            box-shadow: 0 4px 20px rgba(124,58,237,0.45);
          }

          .stack {
            margin-top: 20px;
            display: flex;
            justify-content: center;
            gap: 10px;
            flex-wrap: wrap;
          }
          .tag {
            padding: 4px 12px;
            border-radius: 8px;
            background: rgba(255,255,255,0.07);
            border: 1px solid rgba(200,150,255,0.15);
            font-size: 0.75rem;
            color: rgba(255,255,255,0.55);
          }
        </style>
      </head>
      <body>
        <div class="stars"></div>
        <div class="bg-orb bg-orb-1"></div>
        <div class="bg-orb bg-orb-2"></div>

        <div class="card">
          <span class="emoji">🚀</span>
          <h1>Hello, World!</h1>
          <p class="subtitle">Application 2 &mdash; Déploiement Kubernetes</p>
          <div class="divider"></div>
          <div class="badge">
            <span>⚡</span>
            Terraform &bull; k8s &bull; nginx
          </div>
          <div class="stack">
            <span class="tag">namespace: hello-world</span>
            <span class="tag">app: hello-app2</span>
            <span class="tag">✓ running</span>
          </div>
        </div>
      </body>
      </html>
    EOT
  }
}

resource "kubernetes_deployment_v1" "app2" {
  metadata {
    name      = "hello-app2"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "hello-app2"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "hello-app2"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-app2"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = var.nginx_image

          port {
            container_port = 80
            protocol       = "TCP"
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map_v1.app2_html.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app2" {
  metadata {
    name      = "hello-app2"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "hello-app2"
      managed-by = "terraform"
    }
  }

  spec {
    selector = {
      app = "hello-app2"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      node_port   = var.app2_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}
