variable "namespace" {
  type    = string
  default = "traefik"
}

variable "dmz_vlan_ip" {
  description = "IP du VLAN dmz — Traefik (ports 80 et 443)"
  type        = string
}

variable "mgmt_ip" {
  description = "IP management du nœud kube — cible du NAT SNS firewall"
  type        = string
}

variable "image" {
  type    = string
  default = "traefik:v3"
}

variable "cloudflare_api_token" {
  description = "Token API Cloudflare avec permission Zone:DNS:Edit (pour ACME DNS challenge)"
  type        = string
  sensitive   = true
}

variable "acme_host_data_path" {
  description = "Chemin sur le nœud hôte pour stocker acme.json (persistance des certs Let's Encrypt)"
  type        = string
  default     = "/opt/traefik-acme"
}

variable "dashboard_htpasswd" {
  description = "Credentials dashboard au format htpasswd (générer avec : htpasswd -nB user password)"
  type        = string
  sensitive   = true
}
