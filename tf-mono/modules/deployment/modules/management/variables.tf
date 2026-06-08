variable "namespace" {
  type    = string
  default = "management"
}

# ── Loki ─────────────────────────────────────────────────────────

variable "loki_image" {
  type    = string
  default = "grafana/loki:3.3.2"
}

variable "loki_host_data_path" {
  description = "Persistance Loki sur le nœud hôte"
  type        = string
  default     = "/opt/loki"
}

variable "promtail_image" {
  type    = string
  default = "grafana/promtail:3.3.2"
}

# ── Teleport ─────────────────────────────────────────────────────

variable "teleport_image" {
  type    = string
  default = "public.ecr.aws/gravitational/teleport-distroless:17"
}

variable "teleport_vlan_ip" {
  description = "IP exposée pour Teleport (management VLAN — doit être routable vers le nœud kube)"
  type        = string
}

variable "teleport_host_data_path" {
  description = "Persistance Teleport sur le nœud hôte"
  type        = string
  default     = "/opt/teleport"
}

# ── Coder ────────────────────────────────────────────────────────

variable "coder_image" {
  type    = string
  default = "ghcr.io/coder/coder:latest"
}

variable "coder_access_url" {
  type    = string
  default = "https://coder.magnaloca.com"
}

variable "coder_wildcard_access_url" {
  type    = string
  default = "*--apps.coder.magnaloca.com"
}

variable "coder_postgres_password" {
  type      = string
  sensitive = true
}

variable "coder_host_data_path" {
  description = "Persistance PostgreSQL de Coder sur le nœud hôte"
  type        = string
  default     = "/opt/coder-postgres"
}
