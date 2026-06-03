resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by = "terraform"
      theme      = "matrix"
    }
  }
  timeouts { delete = "15m" }
}

resource "kubernetes_config_map_v1" "html" {
  metadata {
    name      = "hello-matrix-html"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "index.html" = <<-EOT
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hello World — Matrix</title>
        <style>
          *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #000;
            font-family: 'Courier New', 'Lucida Console', monospace;
            color: #00ff41;
            overflow: hidden;
          }

          canvas {
            position: fixed;
            inset: 0;
            opacity: 0.18;
          }

          .scanlines {
            position: fixed;
            inset: 0;
            background: repeating-linear-gradient(
              0deg,
              transparent,
              transparent 2px,
              rgba(0,0,0,0.15) 2px,
              rgba(0,0,0,0.15) 4px
            );
            pointer-events: none;
          }

          .card {
            position: relative;
            background: rgba(0,10,0,0.85);
            border: 1px solid #00ff41;
            border-radius: 2px;
            padding: 56px 72px;
            text-align: center;
            box-shadow:
              0 0 20px rgba(0,255,65,0.15),
              0 0 60px rgba(0,255,65,0.06),
              inset 0 0 30px rgba(0,255,65,0.04);
            max-width: 560px;
            width: 90vw;
          }

          .corner {
            position: absolute;
            width: 16px;
            height: 16px;
            border-color: #00ff41;
            border-style: solid;
            opacity: 0.7;
          }
          .corner-tl { top: 8px;  left: 8px;  border-width: 2px 0 0 2px; }
          .corner-tr { top: 8px;  right: 8px; border-width: 2px 2px 0 0; }
          .corner-bl { bottom: 8px; left: 8px;  border-width: 0 0 2px 2px; }
          .corner-br { bottom: 8px; right: 8px; border-width: 0 2px 2px 0; }

          .pill-row {
            display: flex;
            justify-content: center;
            gap: 32px;
            margin-bottom: 30px;
          }
          .pill {
            font-size: 2.4rem;
            animation: blink-pill 2s ease-in-out infinite;
          }
          .pill.red  { filter: drop-shadow(0 0 6px #ff2222); animation-delay: -1s; }
          .pill.blue { filter: drop-shadow(0 0 6px #2244ff); }
          @keyframes blink-pill {
            0%, 100% { opacity: 1;   transform: scale(1);    }
            50%       { opacity: 0.7; transform: scale(0.95); }
          }

          .hero {
            font-size: 4.5rem;
            display: block;
            margin-bottom: 22px;
            animation: pulse-green 1.5s ease-in-out infinite;
            filter: drop-shadow(0 0 12px rgba(0,255,65,0.8));
          }
          @keyframes pulse-green {
            0%, 100% { filter: drop-shadow(0 0 8px  rgba(0,255,65,0.6)); }
            50%       { filter: drop-shadow(0 0 22px rgba(0,255,65,1));   }
          }

          h1 {
            font-size: clamp(1.8rem, 5vw, 2.8rem);
            font-weight: 700;
            letter-spacing: 6px;
            text-transform: uppercase;
            color: #00ff41;
            text-shadow: 0 0 10px rgba(0,255,65,0.6);
            margin-bottom: 6px;
          }

          .subtitle {
            color: rgba(0,255,65,0.5);
            font-size: 0.78rem;
            letter-spacing: 4px;
            text-transform: uppercase;
            margin-bottom: 28px;
          }

          .divider {
            height: 1px;
            background: linear-gradient(90deg, transparent, #00ff41, transparent);
            opacity: 0.3;
            margin: 22px 0;
          }

          .terminal {
            background: rgba(0,255,65,0.04);
            border: 1px solid rgba(0,255,65,0.2);
            padding: 14px 20px;
            border-radius: 2px;
            text-align: left;
            font-size: 0.78rem;
            line-height: 1.9;
            color: rgba(0,255,65,0.8);
            margin-bottom: 20px;
          }
          .prompt { color: rgba(0,255,65,0.4); }
          .cmd    { color: #00ff41; }
          .out    { color: rgba(0,255,65,0.6); }

          .cursor {
            display: inline-block;
            width: 8px;
            height: 14px;
            background: #00ff41;
            vertical-align: middle;
            animation: blink-cursor 1s step-end infinite;
          }
          @keyframes blink-cursor {
            0%, 100% { opacity: 1; }
            50%       { opacity: 0; }
          }

          .tags {
            display: flex;
            justify-content: center;
            gap: 8px;
            flex-wrap: wrap;
          }
          .tag {
            padding: 4px 10px;
            background: rgba(0,255,65,0.06);
            border: 1px solid rgba(0,255,65,0.25);
            border-radius: 2px;
            font-size: 0.7rem;
            color: rgba(0,255,65,0.55);
            letter-spacing: 1px;
          }
        </style>
      </head>
      <body>
        <canvas id="matrix"></canvas>
        <div class="scanlines"></div>

        <div class="card">
          <div class="corner corner-tl"></div>
          <div class="corner corner-tr"></div>
          <div class="corner corner-bl"></div>
          <div class="corner corner-br"></div>

          <div class="pill-row">
            <span class="pill red">💊</span>
            <span class="pill blue">💊</span>
          </div>

          <span class="hero">🟩</span>
          <h1>Hello, World!</h1>
          <p class="subtitle">Wake up, Neo&hellip; the cluster has you</p>

          <div class="divider"></div>

          <div class="terminal">
            <div><span class="prompt">$</span> <span class="cmd">kubectl get pods -n hello-world</span></div>
            <div><span class="out">hello-matrix-xxx&nbsp;&nbsp;&nbsp;1/1&nbsp;&nbsp;&nbsp;Running&nbsp;&nbsp;&nbsp;0&nbsp;&nbsp;&nbsp;1m</span></div>
            <div><span class="prompt">$</span> <span class="cursor"></span></div>
          </div>

          <div class="tags">
            <span class="tag">namespace: hello-world</span>
            <span class="tag">app: matrix</span>
            <span class="tag">✓ running</span>
          </div>
        </div>

        <script>
          const c = document.getElementById('matrix');
          const ctx = c.getContext('2d');
          function resize() { c.width = window.innerWidth; c.height = window.innerHeight; }
          resize();
          window.addEventListener('resize', resize);
          const chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEF';
          const cols = Math.floor(c.width / 18);
          const drops = Array(cols).fill(1);
          setInterval(() => {
            ctx.fillStyle = 'rgba(0,0,0,0.05)';
            ctx.fillRect(0, 0, c.width, c.height);
            ctx.fillStyle = '#00ff41';
            ctx.font = '15px Courier New';
            drops.forEach((y, i) => {
              ctx.fillText(chars[Math.floor(Math.random() * chars.length)], i * 18, y * 18);
              if (y * 18 > c.height && Math.random() > 0.975) drops[i] = 0;
              drops[i]++;
            });
          }, 50);
        </script>
      </body>
      </html>
    EOT
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = "hello-matrix"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "hello-matrix"
      managed-by = "terraform"
      theme      = "matrix"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "hello-matrix" }
    }

    template {
      metadata {
        labels = { app = "hello-matrix" }
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
    name      = "hello-matrix"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "hello-matrix"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "hello-matrix" }
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
