variable "namespace" {
  type    = string
  default = "traefik"
}

variable "dmz_vlan_ip" {
  description = "IP du VLAN dmz — Traefik écoutera sur cette IP (ports 80 et 443)"
  type        = string
}

variable "image" {
  type    = string
  default = "traefik:v3"
}
