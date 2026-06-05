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
  description = "Mot de passe PostgreSQL (Affine + Ghostfolio)"
  type        = string
  sensitive   = true
}

variable "mariadb_password" {
  description = "Mot de passe MariaDB pour Passbolt"
  type        = string
  sensitive   = true
}

variable "passbolt_app_url" {
  description = "URL complète de Passbolt (ex: http://10.0.5.200:8080)"
  type        = string
}

variable "passbolt_gpg_fingerprint" {
  description = "Empreinte GPG Passbolt — vide au 1er déploiement, récupérer via: kubectl logs -n perso deploy/passbolt | grep -i fingerprint"
  type        = string
  default     = ""
}

variable "ghostfolio_secret" {
  description = "Clé secrète Ghostfolio (ACCESS_TOKEN_SALT + JWT_SECRET_KEY)"
  type        = string
  sensitive   = true
}

# ── Images ──────────────────────────────────────────────────────

variable "postgres_image" {
  type    = string
  default = "postgres:16-alpine"
}

variable "mariadb_image" {
  type    = string
  default = "mariadb:11"
}

variable "redis_image" {
  type    = string
  default = "redis:7-alpine"
}

variable "passbolt_image" {
  type    = string
  default = "passbolt/passbolt:4-ce-non-root"
}

variable "affine_image" {
  type    = string
  default = "ghcr.io/toeverything/affine-graphql:stable"
}

variable "nextexplorer_image" {
  description = "Image NextExplorer — filebrowser par défaut, à remplacer si besoin"
  type        = string
  default     = "filebrowser/filebrowser:latest"
}

variable "ghostfolio_image" {
  type    = string
  default = "ghostfolio/ghostfolio:latest"
}
