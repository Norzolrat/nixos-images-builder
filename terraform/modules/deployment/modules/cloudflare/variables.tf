variable "namespace" {
  type    = string
  default = "cloudflare"
}

variable "tunnel_token" {
  description = "Token du tunnel Cloudflare (Zero Trust > Networks > Tunnels > Configure > Token)"
  type        = string
  sensitive   = true
}

variable "image" {
  type    = string
  default = "cloudflare/cloudflared:latest"
}

variable "replicas" {
  description = "Nombre de replicas cloudflared (1 sur single-node, 2 pour la HA multi-node)"
  type        = number
  default     = 1
}
