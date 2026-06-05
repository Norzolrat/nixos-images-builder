# ════════════════════════════════════════════════════════════════
#  Module llm-stack — tf-mono
#  Ollama · Open-WebUI · ComfyUI · SearXNG
#
#  APIs accessibles sur le VLAN ai via externalIPs :
#    Ollama     → http://<ai_vlan_ip>:11434
#    Open-WebUI → http://<ai_vlan_ip>:8080
#    ComfyUI    → http://<ai_vlan_ip>:8188  (si activé)
#    SearXNG    → http://<ai_vlan_ip>:8085  (si activé)
#
#  Le master est le nœud GPU : toleration control-plane requise.
# ════════════════════════════════════════════════════════════════

# ── Namespace ────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "llm-stack"
      environment = "ai"
    }
  }
  timeouts { delete = "15m" }
}

# ════════════════════════════════════════════════════════════════
#  OLLAMA — LLM inference server  🦙
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "ollama" {
  wait_for_rollout = false

  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "ollama"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "ollama" }
    }

    strategy { type = "Recreate" }

    template {
      metadata {
        labels = { app = "ollama" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        host_ipc = true

        security_context {
          supplemental_groups = [var.render_group_id, var.video_group_id]
          seccomp_profile { type = "Unconfined" }
        }

        container {
          name  = "ollama"
          image = var.ollama_image

          port {
            name           = "api"
            container_port = 11434
            protocol       = "TCP"
          }

          env {
            name  = "HIP_VISIBLE_DEVICES"
            value = var.hip_visible_devices
          }
          env {
            name  = "ROCR_VISIBLE_DEVICES"
            value = var.hip_visible_devices
          }
          env {
            name  = "OLLAMA_DEBUG"
            value = "INFO"
          }

          resources {
            requests = {
              cpu    = var.ollama_cpu_request
              memory = var.ollama_memory_request
            }
            limits = {
              memory = var.ollama_memory_limit
            }
          }

          security_context { privileged = true }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama/models"
          }
          volume_mount {
            name       = "dev-kfd"
            mount_path = "/dev/kfd"
          }
          volume_mount {
            name       = "dev-dri"
            mount_path = "/dev/dri"
          }
        }

        volume {
          name = "models"
          host_path {
            path = "${var.host_data_path}/ollama/models"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "dev-kfd"
          host_path {
            path = "/dev/kfd"
            type = "CharDevice"
          }
        }
        volume {
          name = "dev-dri"
          host_path {
            path = "/dev/dri"
            type = "Directory"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "ollama"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "ollama" }
    type         = "ClusterIP"
    external_ips = [var.ai_vlan_ip]

    port {
      name        = "api"
      port        = 11434
      target_port = 11434
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  OPEN-WEBUI — Interface LLM + Images  🌐
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "open_webui" {
  wait_for_rollout = false

  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "open-webui"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "open-webui" }
    }

    strategy { type = "Recreate" }

    template {
      metadata {
        labels = { app = "open-webui" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name  = "open-webui"
          image = var.open_webui_image

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "OLLAMA_BASE_URL"
            value = "http://ollama.${var.namespace}.svc.cluster.local:11434"
          }
          env {
            name  = "ENABLE_IMAGE_GENERATION"
            value = tostring(var.enable_comfyui)
          }
          env {
            name  = "IMAGE_GENERATION_ENGINE"
            value = "comfyui"
          }
          env {
            name  = "COMFYUI_BASE_URL"
            value = "http://${var.ai_vlan_ip}:8188"
          }
          env {
            name  = "WEBUI_AUTH"
            value = "true"
          }
          env {
            name  = "ENABLE_RAG_LOCAL_WEB_FETCH"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              memory = "2Gi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/app/backend/data"
          }
        }

        volume {
          name = "data"
          host_path {
            path = "${var.host_data_path}/open-webui"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.ollama]
}

resource "kubernetes_service_v1" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "open-webui"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "open-webui" }
    type         = "ClusterIP"
    external_ips = [var.ai_vlan_ip]

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  COMFYUI — Stable Diffusion UI  🎨  (optionnel)
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "comfyui" {
  count            = var.enable_comfyui ? 1 : 0
  wait_for_rollout = false

  metadata {
    name      = "comfyui"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "comfyui"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "comfyui" }
    }

    strategy { type = "Recreate" }

    template {
      metadata {
        labels = { app = "comfyui" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        host_ipc = true

        security_context {
          supplemental_groups = [var.render_group_id, var.video_group_id]
          seccomp_profile { type = "Unconfined" }
        }

        container {
          name  = "comfyui"
          image = var.comfyui_image
          command = [
            "python", "main.py",
            "--listen", "0.0.0.0",
            "--port", "8188",
            "--fp8_e4m3fn-unet",
            "--fp8_e4m3fn-text-enc",
          ]

          port {
            name           = "ui"
            container_port = 8188
            protocol       = "TCP"
          }

          env {
            name  = "HIP_VISIBLE_DEVICES"
            value = var.hip_visible_devices
          }
          env {
            name  = "PYTORCH_HIP_ALLOC_CONF"
            value = "expandable_segments:True"
          }
          env {
            name  = "HSA_ENABLE_SDMA"
            value = "0"
          }

          resources {
            requests = {
              memory = var.comfyui_memory_request
            }
          }

          security_context { privileged = true }

          volume_mount {
            name       = "models"
            mount_path = "/workspace/ComfyUI/models"
          }
          volume_mount {
            name       = "output"
            mount_path = "/workspace/ComfyUI/output"
          }
          volume_mount {
            name       = "input"
            mount_path = "/workspace/ComfyUI/input"
          }
          volume_mount {
            name       = "custom-nodes"
            mount_path = "/workspace/ComfyUI/custom_nodes"
          }
          volume_mount {
            name       = "user"
            mount_path = "/workspace/ComfyUI/user"
          }
          volume_mount {
            name       = "dev-kfd"
            mount_path = "/dev/kfd"
          }
          volume_mount {
            name       = "dev-dri"
            mount_path = "/dev/dri"
          }
        }

        volume {
          name = "models"
          host_path {
            path = "${var.host_data_path}/comfyui/models"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "output"
          host_path {
            path = "${var.host_data_path}/comfyui/output"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "input"
          host_path {
            path = "${var.host_data_path}/comfyui/input"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "custom-nodes"
          host_path {
            path = "${var.host_data_path}/comfyui/custom_nodes"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "user"
          host_path {
            path = "${var.host_data_path}/comfyui/user"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "dev-kfd"
          host_path {
            path = "/dev/kfd"
            type = "CharDevice"
          }
        }
        volume {
          name = "dev-dri"
          host_path {
            path = "/dev/dri"
            type = "Directory"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "comfyui" {
  count = var.enable_comfyui ? 1 : 0

  metadata {
    name      = "comfyui"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "comfyui"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "comfyui" }
    type         = "ClusterIP"
    external_ips = [var.ai_vlan_ip]

    port {
      name        = "ui"
      port        = 8188
      target_port = 8188
      protocol    = "TCP"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  SEARXNG — Moteur de recherche privé  🔍  (optionnel)
# ════════════════════════════════════════════════════════════════

resource "kubernetes_config_map_v1" "searxng_config" {
  count = var.enable_searxng ? 1 : 0

  metadata {
    name      = "searxng-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "searxng"
      managed-by = "terraform"
    }
  }

  data = {
    "settings.yml" = <<-YAML
      use_default_settings: true

      server:
        secret_key: "${var.searxng_secret_key}"
        bind_address: "0.0.0.0:8080"
        image_proxy: true

      ui:
        default_locale: "fr"
        default_theme: simple
        infinite_scroll: true

      search:
        safe_search: 0
        autocomplete: "google"
        default_lang: "fr-FR"

      engines:
        - name: google
          engine: google
          shortcut: g
          use_mobile_ui: false
        - name: duckduckgo
          engine: duckduckgo
          shortcut: d
        - name: wikipedia
          engine: wikipedia
          shortcut: w
          language: fr
        - name: github
          engine: github
          shortcut: gh
        - name: stackoverflow
          engine: stackoverflow
          shortcut: so
    YAML
  }
}

resource "kubernetes_deployment_v1" "searxng" {
  count            = var.enable_searxng ? 1 : 0
  wait_for_rollout = false

  metadata {
    name      = "searxng"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "searxng"
      managed-by = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "searxng" }
    }

    template {
      metadata {
        labels = { app = "searxng" }
      }

      spec {
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        enable_service_links = false

        security_context {
          run_as_non_root = true
          run_as_user     = 977
          run_as_group    = 977
        }

        container {
          name  = "searxng"
          image = var.searxng_image

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "INSTANCE_NAME"
            value = "llm-stack-search"
          }
          env {
            name  = "SEARXNG_PORT"
            value = "8080"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/searxng/settings.yml"
            sub_path   = "settings.yml"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.searxng_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "searxng" {
  count = var.enable_searxng ? 1 : 0

  metadata {
    name      = "searxng"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app        = "searxng"
      managed-by = "terraform"
    }
  }

  spec {
    selector     = { app = "searxng" }
    type         = "ClusterIP"
    external_ips = [var.ai_vlan_ip]

    port {
      name        = "http"
      port        = 8085
      target_port = 8080
      protocol    = "TCP"
    }
  }
}
