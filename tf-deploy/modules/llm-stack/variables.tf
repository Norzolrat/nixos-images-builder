# ════════════════════════════════════════════════════════════════
#  Module llm-stack — Variables
#  Ollama · ComfyUI · Open-WebUI · SearXNG  on AMD ROCm / K8s
# ════════════════════════════════════════════════════════════════

# ── Namespace ────────────────────────────────────────────────────

variable "namespace" {
  description = "Namespace Kubernetes pour la stack LLM"
  type        = string
  default     = "llm"
}

# ── Node GPU ─────────────────────────────────────────────────────

variable "gpu_node_label_key" {
  description = "Clé du label du node GPU"
  type        = string
  default     = "gpu"
}

variable "gpu_node_label_value" {
  description = "Valeur du label du node GPU"
  type        = string
  default     = "amd"
}

variable "gpu_node_ip" {
  description = "IP du node GPU — utilisée pour les URLs NodePort accessibles hors cluster"
  type        = string
  default     = "192.168.99.189"
}

# ── Images Docker ────────────────────────────────────────────────

variable "ollama_image" {
  description = "Image Ollama avec support ROCm"
  type        = string
  default     = "ollama/ollama:rocm"
}

variable "comfyui_image" {
  description = "Image ComfyUI avec support ROCm"
  type        = string
  default     = "corundex/comfyui-rocm:latest"
}

variable "open_webui_image" {
  description = "Image Open-WebUI"
  type        = string
  default     = "ghcr.io/open-webui/open-webui:main"
}

variable "searxng_image" {
  description = "Image SearXNG"
  type        = string
  default     = "searxng/searxng:latest"
}

# ── Stockage (HostPath sur le node GPU) ──────────────────────────

variable "host_data_path" {
  description = "Chemin de base sur le node GPU pour les données persistantes"
  type        = string
  default     = "/opt/llm"
}

# ── NodePorts ────────────────────────────────────────────────────

variable "ollama_node_port" {
  description = "NodePort exposé pour l'API Ollama"
  type        = number
  default     = 30434
}

variable "comfyui_node_port" {
  description = "NodePort exposé pour ComfyUI"
  type        = number
  default     = 30188
}

variable "open_webui_node_port" {
  description = "NodePort exposé pour Open-WebUI"
  type        = number
  default     = 30300
}

variable "searxng_node_port" {
  description = "NodePort exposé pour SearXNG"
  type        = number
  default     = 30810
}

# ── GPU / ROCm ───────────────────────────────────────────────────

variable "hip_visible_devices" {
  description = "Index du GPU AMD visible (HIP_VISIBLE_DEVICES)"
  type        = string
  default     = "0"
}

variable "render_group_id" {
  description = "GID du groupe 'render' sur le node host (pour /dev/dri)"
  type        = number
  default     = 993
}

variable "video_group_id" {
  description = "GID du groupe 'video' sur le node host (pour /dev/kfd)"
  type        = number
  default     = 44
}

# ── Activation des services optionnels ──────────────────────────

variable "enable_comfyui" {
  description = "Déployer ComfyUI (Stable Diffusion). Désactiver pour alléger le cluster au démarrage."
  type        = bool
  default     = false
}

variable "enable_searxng" {
  description = "Déployer SearXNG (moteur de recherche). Désactiver pour alléger le cluster au démarrage."
  type        = bool
  default     = false
}

# ── SearXNG ──────────────────────────────────────────────────────

variable "searxng_secret_key" {
  description = "Clé secrète SearXNG (chaîne aléatoire)"
  type        = string
  sensitive   = true
  default     = "changeme-replace-with-random-secret"
}

variable "searxng_base_url" {
  description = "URL publique de SearXNG (pour les métadonnées)"
  type        = string
  default     = "http://localhost:30810"
}

# ── Ressources Ollama ────────────────────────────────────────────

variable "ollama_memory_request" {
  type    = string
  default = "2Gi"
}

variable "ollama_memory_limit" {
  type    = string
  default = "12Gi"
}

variable "ollama_cpu_request" {
  type    = string
  default = "500m"
}

# ── Ressources ComfyUI ───────────────────────────────────────────

variable "comfyui_memory_request" {
  type    = string
  default = "4Gi"
}
