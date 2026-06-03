resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by = "terraform"
      theme      = "mario"
    }
  }
  timeouts { delete = "15m" }
}

resource "kubernetes_config_map_v1" "html" {
  metadata {
    name      = "hello-mario-html"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "index.html" = <<-EOT
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hello World — Mario</title>
        <style>
          *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(180deg, #5c94fc 0%, #5c94fc 60%, #e86a17 60%, #e86a17 75%, #7bc855 75%, #7bc855 100%);
            font-family: 'Courier New', 'Lucida Console', monospace;
            color: #fff;
            overflow: hidden;
            image-rendering: pixelated;
          }

          .clouds {
            position: fixed;
            top: 8%;
            width: 100%;
            display: flex;
            justify-content: space-around;
            pointer-events: none;
          }
          .cloud {
            font-size: 3rem;
            opacity: 0.85;
            animation: float-cloud 12s ease-in-out infinite;
          }
          .cloud:nth-child(2) { animation-delay: -5s; font-size: 2.2rem; }
          .cloud:nth-child(3) { animation-delay: -9s; font-size: 2.6rem; }
          @keyframes float-cloud {
            0%, 100% { transform: translateX(0); }
            50%       { transform: translateX(18px); }
          }

          .ground {
            position: fixed;
            bottom: 0;
            width: 100%;
            height: 60px;
            display: flex;
            gap: 0;
            pointer-events: none;
          }
          .block {
            width: 60px;
            height: 60px;
            background: #c84b0f;
            border: 4px solid #7a2d08;
            border-bottom: none;
            flex-shrink: 0;
          }
          .block:nth-child(odd) { background: #e07010; }

          .card {
            position: relative;
            background: rgba(0,0,0,0.72);
            border: 6px solid #e8d000;
            border-radius: 4px;
            padding: 52px 72px;
            text-align: center;
            box-shadow:
              0 0 0 10px rgba(0,0,0,0.4),
              0 0 40px rgba(232,208,0,0.3),
              6px 6px 0 #7a6800;
            max-width: 540px;
            width: 90vw;
          }

          .coin-row {
            display: flex;
            justify-content: center;
            gap: 14px;
            margin-bottom: 28px;
          }
          .coin {
            font-size: 2.2rem;
            animation: coin-spin 1s steps(4) infinite;
          }
          .coin:nth-child(2) { animation-delay: 0.25s; }
          .coin:nth-child(3) { animation-delay: 0.5s; }
          .coin:nth-child(4) { animation-delay: 0.75s; }
          @keyframes coin-spin {
            0%   { transform: scaleX(1); }
            25%  { transform: scaleX(0.5); }
            50%  { transform: scaleX(0.1); }
            75%  { transform: scaleX(0.5); }
            100% { transform: scaleX(1); }
          }

          .hero {
            font-size: 5rem;
            line-height: 1;
            margin-bottom: 20px;
            display: block;
            animation: jump 1.2s ease-in-out infinite;
            filter: drop-shadow(0 0 12px rgba(255,200,0,0.7));
          }
          @keyframes jump {
            0%, 100% { transform: translateY(0); }
            45%       { transform: translateY(-18px); }
            55%       { transform: translateY(-18px); }
          }

          h1 {
            font-size: clamp(1.8rem, 5vw, 2.8rem);
            font-weight: 900;
            letter-spacing: 4px;
            text-transform: uppercase;
            color: #e8d000;
            text-shadow:
              3px 3px 0 #7a6800,
              -2px -2px 0 #a08000;
            margin-bottom: 10px;
          }

          .subtitle {
            color: rgba(255,255,255,0.65);
            font-size: 0.85rem;
            letter-spacing: 2px;
            text-transform: uppercase;
            margin-bottom: 26px;
          }

          .score-board {
            display: flex;
            justify-content: center;
            gap: 32px;
            background: rgba(0,0,0,0.5);
            border: 3px solid #e8d000;
            border-radius: 2px;
            padding: 12px 24px;
            margin-bottom: 20px;
          }
          .score-item { text-align: center; }
          .score-label {
            font-size: 0.65rem;
            letter-spacing: 2px;
            text-transform: uppercase;
            color: #e8d000;
          }
          .score-value {
            font-size: 1.2rem;
            font-weight: 700;
            color: #fff;
            letter-spacing: 1px;
          }

          .tags {
            display: flex;
            justify-content: center;
            gap: 8px;
            flex-wrap: wrap;
            margin-top: 8px;
          }
          .tag {
            padding: 4px 10px;
            background: rgba(232,208,0,0.15);
            border: 2px solid rgba(232,208,0,0.4);
            border-radius: 2px;
            font-size: 0.7rem;
            color: rgba(255,255,255,0.6);
            letter-spacing: 1px;
          }
        </style>
      </head>
      <body>
        <div class="clouds">
          <span class="cloud">☁️</span>
          <span class="cloud">☁️</span>
          <span class="cloud">☁️</span>
        </div>

        <div class="ground">
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
          <div class="block"></div><div class="block"></div><div class="block"></div>
        </div>

        <div class="card">
          <div class="coin-row">
            <span class="coin">🪙</span>
            <span class="coin">🪙</span>
            <span class="coin">🪙</span>
            <span class="coin">🪙</span>
          </div>

          <span class="hero">🍄</span>
          <h1>Hello, World!</h1>
          <p class="subtitle">World 1-1 &mdash; Kubernetes</p>

          <div class="score-board">
            <div class="score-item">
              <div class="score-label">Namespace</div>
              <div class="score-value">hello-world</div>
            </div>
            <div class="score-item">
              <div class="score-label">App</div>
              <div class="score-value">mario</div>
            </div>
            <div class="score-item">
              <div class="score-label">Status</div>
              <div class="score-value">✓ RUN</div>
            </div>
          </div>

          <div class="tags">
            <span class="tag">NixOS</span>
            <span class="tag">kubeadm</span>
            <span class="tag">nginx</span>
            <span class="tag">terraform</span>
          </div>
        </div>
      </body>
      </html>
    EOT
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = "hello-mario"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "hello-mario"
      managed-by = "terraform"
      theme      = "mario"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "hello-mario" }
    }

    template {
      metadata {
        labels = { app = "hello-mario" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

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
            requests = { cpu = "50m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "64Mi" }
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map_v1.html.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = "hello-mario"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "hello-mario"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "hello-mario" }
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
