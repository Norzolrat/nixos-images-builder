# ========================================
# Kubernetes
# ========================================

variable "kubeconfig_path" {
  description = "Chemin vers le kubeconfig exporté par tf-kube"
  type        = string
  default     = "../export/kubeconfig"
}

# ========================================
# Déploiements
# ========================================

variable "namespace" {
  description = "Namespace Kubernetes pour les déploiements hello-world"
  type        = string
  default     = "hello-world"
}

variable "replicas" {
  description = "Nombre de replicas pour chaque déploiement nginx"
  type        = number
  default     = 2
}

variable "nginx_image" {
  description = "Image Docker nginx à utiliser"
  type        = string
  default     = "nginx:alpine"
}

# ========================================
# Exposition (NodePort)
# ========================================

variable "app1_node_port" {
  description = "NodePort exposé pour l'application 1 (thème Océan)"
  type        = number
  default     = 30080
}

variable "app2_node_port" {
  description = "NodePort exposé pour l'application 2 (thème Cosmos)"
  type        = number
  default     = 30081
}

variable "node_ip" {
  description = "IP d'un nœud du cluster (pour afficher les URLs dans les outputs)"
  type        = string
  default     = "192.168.99.186"
}

# ========================================
# Cloudflare Tunnel
# ========================================

variable "cloudflare_tunnel_token" {
  description = "Token du tunnel Cloudflare (Zero Trust > Networks > Tunnels > dc-kube > Configure > Token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflared_image" {
  description = "Image Docker cloudflared"
  type        = string
  default     = "cloudflare/cloudflared:latest"
}
