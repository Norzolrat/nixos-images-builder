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

variable "mario_external_ip" {
  description = "IP du VLAN pour Mario 🍄 (VLAN dmz)"
  type        = string
}

variable "starwars_external_ip" {
  description = "IP du VLAN pour Star Wars ⚔️ (VLAN perso)"
  type        = string
}

variable "matrix_external_ip" {
  description = "IP du VLAN pour Matrix 💊 (VLAN ai)"
  type        = string
}
