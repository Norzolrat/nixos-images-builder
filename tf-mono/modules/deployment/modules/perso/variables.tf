variable "namespace" {
  type = string
}

variable "perso_vlan_ip" {
  description = "IP du VLAN perso exposée sur les services"
  type        = string
}

variable "host_data_path" {
  description = "Chemin de base sur le node pour les données persistantes"
  type        = string
  default     = "/opt/perso"
}

variable "postgres_password" {
  description = "Mot de passe PostgreSQL (Affine + Ghostfolio + Passbolt)"
  type        = string
  sensitive   = true
}

variable "passbolt_app_url" {
  description = "URL complète de Passbolt (ex: http://10.0.5.200:8080)"
  type        = string
}

variable "passbolt_gpg_fingerprint" {
  description = "Empreinte GPG du serveur Passbolt"
  type        = string
}

variable "passbolt_gpg_public_key" {
  description = "Clé publique GPG du serveur Passbolt (format armor)"
  type        = string
}

variable "passbolt_gpg_private_key" {
  description = "Clé privée GPG du serveur Passbolt (format armor)"
  type        = string
  sensitive   = true
}

variable "ghostfolio_secret" {
  description = "Clé secrète Ghostfolio (ACCESS_TOKEN_SALT + JWT_SECRET_KEY)"
  type        = string
  sensitive   = true
}

# ── Images ──────────────────────────────────────────────────────

variable "postgres_image" {
  type    = string
  default = "pgvector/pgvector:pg16"
}

variable "redis_image" {
  type    = string
  default = "redis:7-alpine"
}

variable "passbolt_image" {
  type    = string
  default = "passbolt/passbolt:latest"
}

variable "affine_image" {
  type    = string
  default = "ghcr.io/toeverything/affine:stable"
}

variable "ghostfolio_image" {
  type    = string
  default = "ghostfolio/ghostfolio:latest"
}
