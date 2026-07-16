# ========================================
# MetalLB
# ========================================

variable "metallb_version" {
  description = "Version du chart Helm MetalLB"
  type        = string
  default     = "0.14.9"
}

variable "vlan_subinterfaces" {
  description = "Subinterfaces VLAN transmises à MetalLB pour créer les IPAddressPool"
  type = list(object({
    name    = string
    vlan_id = number
    ip      = string
  }))
  default = []
}

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

variable "traefik_mgmt_ip" {
  description = "IP management du nœud kube (cible NAT SNS)"
  type        = string
  default     = "10.255.255.54"
}

variable "traefik_cloudflare_api_token" {
  description = "Token Cloudflare DNS pour ACME (Zone:DNS:Edit)"
  type        = string
  sensitive   = true
}

variable "traefik_acme_host_data_path" {
  description = "Chemin persistance acme.json sur le nœud hôte"
  type        = string
  default     = "/opt/traefik-acme"
}

variable "traefik_dashboard_htpasswd" {
  description = "Credentials dashboard au format htpasswd (générer avec : htpasswd -nB user password)"
  type        = string
  sensitive   = true
}

# ========================================
# Management — Teleport
# ========================================

variable "teleport_vlan_ip" {
  description = "IP exposée pour Teleport sur le VLAN management (10.255.255.x)"
  type        = string
}

variable "teleport_host_data_path" {
  description = "Chemin persistance Teleport sur le nœud hôte"
  type        = string
  default     = "/opt/teleport"
}

variable "coder_postgres_password" {
  type      = string
  sensitive = true
}

variable "coder_access_url" {
  type    = string
  default = "https://coder.magnaloca.com"
}

variable "coder_wildcard_access_url" {
  type    = string
  default = "*--apps.coder.magnaloca.com"
}

variable "coder_host_data_path" {
  type    = string
  default = "/opt/coder-postgres"
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
