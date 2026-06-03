variable "namespace" {
  type = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "nginx_image" {
  type    = string
  default = "nginx:alpine"
}

variable "external_ip" {
  description = "IP du VLAN exposée sur le port 80"
  type        = string
}
