# ========================================
# Configuration Proxmox
# ========================================

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "proxmox_storage" {
  type    = string
  default = "local"
}

variable "proxmox_datastore_snippets" {
  type    = string
  default = "local"
}

# ========================================
# Configuration VM
# ========================================

variable "vm_hostname" {
  type    = string
  default = "kubeadm-master-01"
}

variable "vm_id" {
  type    = number
  default = 9001
}

variable "nixos_image_file_id" {
  description = "ID du fichier qcow2 NixOS uploadé sur Proxmox (proxmox_virtual_environment_file.id)"
  type        = string
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 20
}

variable "vm_tags" {
  type    = list(string)
  default = ["nixos", "kubeadm", "master"]
}

# ========================================
# Configuration Réseau
# ========================================

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vm_ip" {
  type = string
}

variable "vm_gateway" {
  type = string
}

variable "vm_nameserver" {
  type    = string
  default = "1.1.1.1"
}

# ========================================
# Configuration kubeadm
# ========================================

variable "pod_network_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "calico_version" {
  type    = string
  default = "3.29.3"
}

# ========================================
# Configuration Utilisateur & SSH
# ========================================

variable "manager_user" {
  type    = string
  default = "user"
}

variable "manager_ssh_public_key" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

# ========================================
# Configuration Système
# ========================================

variable "timezone" {
  type    = string
  default = "Europe/Paris"
}
