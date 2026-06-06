# ========================================
# Général
# ========================================

variable "replicas" {
  description = "Nombre de replicas pour chaque déploiement"
  type        = number
  default     = 1
}

variable "nginx_image" {
  description = "Image Docker nginx"
  type        = string
  default     = "nginx:alpine"
}

# ========================================
# IPs externes (une par VLAN)
# ========================================

variable "vlan1_external_ip" {
  description = "IP du VLAN 1 (VLAN dmz)"
  type        = string
}

variable "vlan10_external_ip" {
  description = "IP du VLAN 10 (VLAN perso)"
  type        = string
}

variable "vlan5_external_ip" {
  description = "IP du VLAN 5 (VLAN ai)"
  type        = string
}

# ========================================
# Cloudflare Tunnel
# ========================================

variable "cloudflare_tunnel_token" {
  description = "Token du tunnel Cloudflare (Zero Trust > Networks > Tunnels > Configure > Token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflared_image" {
  type    = string
  default = "cloudflare/cloudflared:latest"
}

# ========================================
# Traefik (VLAN dmz)
# ========================================

variable "dmz_vlan_ip" {
  description = "IP du VLAN dmz pour Traefik"
  type        = string
}

# ========================================
# Perso Stack
# ========================================

variable "perso_vlan_ip" {
  description = "IP du VLAN perso pour les services personnels"
  type        = string
}

variable "perso_host_data_path" {
  type    = string
  default = "/opt/perso"
}

variable "perso_postgres_password" {
  type      = string
  sensitive = true
}

variable "perso_passbolt_app_url" {
  type = string
}

variable "perso_passbolt_gpg_fingerprint" {
  type = string
}

variable "perso_passbolt_gpg_public_key" {
  type = string
}

variable "perso_passbolt_gpg_private_key" {
  type      = string
  sensitive = true
}

variable "perso_ghostfolio_secret" {
  type      = string
  sensitive = true
}

# ========================================
# LLM Stack
# ========================================

variable "llm_ai_vlan_ip" {
  description = "IP du VLAN ai pour exposer les APIs LLM"
  type        = string
}

variable "llm_enable_comfyui" {
  type    = bool
  default = false
}

variable "llm_enable_searxng" {
  type    = bool
  default = false
}

variable "llm_searxng_secret_key" {
  type      = string
  sensitive = true
  default   = "changeme-replace-with-random-secret"
}

variable "llm_host_data_path" {
  description = "Chemin de base sur le node pour les données LLM persistantes"
  type        = string
  default     = "/opt/llm"
}
