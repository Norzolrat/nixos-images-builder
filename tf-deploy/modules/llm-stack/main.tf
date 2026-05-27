# ════════════════════════════════════════════════════════════════
#  Module llm-stack
#  Ollama · ComfyUI · Open-WebUI · SearXNG  🤖🎨🌐🔍
# ════════════════════════════════════════════════════════════════
#
#  Tous les services avec GPU (Ollama, ComfyUI) sont épinglés
#  sur le node gpu=amd via nodeSelector.
#  Les données persistent via hostPath sur ce même node.
#
#  Chemins créés automatiquement sur nixos-kube-worker-3 :
#    ${host_data_path}/ollama/models
#    ${host_data_path}/comfyui/{models,output,input,custom_nodes,user}
#    ${host_data_path}/open-webui
#    ${host_data_path}/searxng
# ════════════════════════════════════════════════════════════════

# ── Namespace ────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "llm" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      module      = "llm-stack"
      environment = "ai"
    }
  }
}

# ════════════════════════════════════════════════════════════════
#  OLLAMA — LLM inference server  🦙
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
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

    strategy {
      type = "Recreate" # évite 2 pods GPU simultanés
    }

    template {
      metadata {
        labels = { app = "ollama" }
      }

      spec {
        node_selector = {
          (var.gpu_node_label_key) = var.gpu_node_label_value
        }

        host_ipc = true

        security_context {
          supplemental_groups = [var.render_group_id, var.video_group_id]
          seccomp_profile {
            type = "Unconfined"
          }
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

          security_context {
            privileged = true
          }

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
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
    labels = {
      app        = "ollama"
      managed-by = "terraform"
    }
  }

  spec {
    selector = { app = "ollama" }

    port {
      name        = "api"
      port        = 11434
      target_port = 11434
      node_port   = var.ollama_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

# ════════════════════════════════════════════════════════════════
#  COMFYUI — Stable Diffusion UI  🎨
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "comfyui" {
  count = var.enable_comfyui ? 1 : 0

  metadata {
    name      = "comfyui"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
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

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "comfyui" }
      }

      spec {
        node_selector = {
          (var.gpu_node_label_key) = var.gpu_node_label_value
        }

        host_ipc = true

        security_context {
          supplemental_groups = [var.render_group_id, var.video_group_id]
          seccomp_profile {
            type = "Unconfined"
          }
        }

        container {
          name  = "comfyui"
          image = var.comfyui_image

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
            name  = "MODEL_DOWNLOAD"
            value = "none"
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
            limits = {
              memory = var.comfyui_memory_limit
            }
          }

          security_context {
            privileged = true
          }

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
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
    labels = {
      app        = "comfyui"
      managed-by = "terraform"
    }
  }

  spec {
    selector = { app = "comfyui" }

    port {
      name        = "ui"
      port        = 8188
      target_port = 8188
      node_port   = var.comfyui_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

# ════════════════════════════════════════════════════════════════
#  OPEN-WEBUI — Interface unifiée LLM + Images  🌐
# ════════════════════════════════════════════════════════════════

resource "kubernetes_deployment_v1" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
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

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = { app = "open-webui" }
      }

      spec {
        # Épinglé sur le node GPU pour que les hostPath soient cohérents
        node_selector = {
          (var.gpu_node_label_key) = var.gpu_node_label_value
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
            value = "http://comfyui.${var.namespace}.svc.cluster.local:8188"
          }
          env {
            name  = "WEBUI_AUTH"
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

  depends_on = [
    kubernetes_deployment_v1.ollama,
  ]
}

resource "kubernetes_service_v1" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
    labels = {
      app        = "open-webui"
      managed-by = "terraform"
    }
  }

  spec {
    selector = { app = "open-webui" }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      node_port   = var.open_webui_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

# ════════════════════════════════════════════════════════════════
#  SEARXNG — Moteur de recherche privé  🔍
# ════════════════════════════════════════════════════════════════

resource "kubernetes_config_map_v1" "searxng_config" {
  count = var.enable_searxng ? 1 : 0

  metadata {
    name      = "searxng-config"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
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

    "uwsgi.ini" = <<-INI
      [uwsgi]
      # uWSGI instance to use searxng (see http://uwsgi-docs.readthedocs.io/en/latest/Configuration.html)
      http = 0.0.0.0:8080
      wsgi-file = searx/webapp.py
      callable = app
      workers = 4
      threads = 4
      chunk-size = 8192
      lazy-apps = true
      master = true
      plugin = python3
      buffer-size = 8192
    INI
  }
}

resource "kubernetes_deployment_v1" "searxng" {
  count = var.enable_searxng ? 1 : 0

  metadata {
    name      = "searxng"
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
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
        node_selector = {
          (var.gpu_node_label_key) = var.gpu_node_label_value
        }

        # Désactive l'injection automatique des vars de service K8s
        # (évite que SEARXNG_PORT=tcp://IP:PORT écrase le port de l'app)
        enable_service_links = false

        security_context {
          # SearXNG tourne en tant qu'utilisateur non-root
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
            name  = "BASE_URL"
            value = var.searxng_base_url
          }
          env {
            name  = "INSTANCE_NAME"
            value = "dc-kube-search"
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
    namespace = kubernetes_namespace_v1.llm.metadata[0].name
    labels = {
      app        = "searxng"
      managed-by = "terraform"
    }
  }

  spec {
    selector = { app = "searxng" }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      node_port   = var.searxng_node_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}
