# ── Namespace ────────────────────────────────────────────────────

variable "namespace" {
  description = "Namespace Kubernetes pour la stack LLM"
  type        = string
  default     = "llm"
}

# ── Réseau ───────────────────────────────────────────────────────

variable "ai_vlan_ip" {
  description = "IP du VLAN ai — les APIs seront accessibles sur cette IP"
  type        = string
}

# ── Images Docker ────────────────────────────────────────────────

variable "ollama_image" {
  type    = string
  default = "ollama/ollama:rocm"
}

variable "open_webui_image" {
  type    = string
  default = "ghcr.io/open-webui/open-webui:main"
}

variable "comfyui_image" {
  type    = string
  default = "corundex/comfyui-rocm:latest"
}

variable "searxng_image" {
  type    = string
  default = "searxng/searxng:latest"
}

# ── Stockage (HostPath sur le node) ──────────────────────────────

variable "host_data_path" {
  description = "Chemin de base sur le node pour les données persistantes"
  type        = string
  default     = "/opt/llm"
}

# ── Activation des services optionnels ───────────────────────────

variable "enable_comfyui" {
  type    = bool
  default = false
}

variable "enable_searxng" {
  type    = bool
  default = false
}

# ── SearXNG ──────────────────────────────────────────────────────

variable "searxng_secret_key" {
  type      = string
  sensitive = true
  default   = "changeme-replace-with-random-secret"
}

# ── GPU / ROCm ───────────────────────────────────────────────────

variable "hip_visible_devices" {
  type    = string
  default = "0"
}

variable "render_group_id" {
  description = "GID du groupe 'render' sur le host (pour /dev/dri)"
  type        = number
  default     = 993
}

variable "video_group_id" {
  description = "GID du groupe 'video' sur le host (pour /dev/kfd)"
  type        = number
  default     = 44
}

# ── Ressources ───────────────────────────────────────────────────

variable "ollama_cpu_request" {
  type    = string
  default = "500m"
}

variable "ollama_memory_request" {
  type    = string
  default = "2Gi"
}

variable "ollama_memory_limit" {
  type    = string
  default = "12Gi"
}

variable "comfyui_memory_request" {
  type    = string
  default = "4Gi"
}
