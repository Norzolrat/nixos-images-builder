# ========================================
# Configuration Proxmox
# ========================================

variable "proxmox_api_url" {
  description = "URL de l'API Proxmox"
  type        = string
  default     = "https://192.168.1.1:8006/api2/json"
}

variable "proxmox_user" {
  description = "Utilisateur Proxmox (format: user@pve)"
  type        = string
  default     = "terraform@pve"
}

variable "proxmox_token_name" {
  description = "Nom du token API Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_token" {
  description = "Valeur du token API Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nom du nœud Proxmox où déployer la VM"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Storage Proxmox pour les disques VM"
  type        = string
  default     = "vm-pool"
}

variable "proxmox_datastore_snippets" {
  description = "Datastore Proxmox pour les snippets cloud-init"
  type        = string
  default     = "local"
}

# ========================================
# Configuration SSH Proxmox (pour upload)
# ========================================

variable "proxmox_ssh_user" {
  description = "Utilisateur SSH sur le nœud Proxmox (requis par le provider pour l'upload de fichiers)"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour le nœud Proxmox"
  type        = string
  sensitive   = true
  default     = "~/.ssh/id_ed25519_terraform"
}

# ========================================
# Configuration VM
# ========================================

variable "vm_hostname" {
  description = "Préfixe du nom d'hôte (si vm_count > 1 : <hostname>-1, <hostname>-2, ...)"
  type        = string
  default     = "nixos-base"
}

variable "vm_id" {
  description = "ID de base de la première VM (suivantes = vm_id + N)"
  type        = number
  default     = 9000
}

variable "vm_count" {
  description = "Nombre de VMs à déployer"
  type        = number
  default     = 1
}

variable "nixos_image_file_id" {
  description = "ID Proxmox du qcow2 pré-uploadé (format: local:iso/nixos-base.qcow2)"
  type        = string
  default     = "local:iso/nixos-base.qcow2"
}

variable "vm_memory" {
  description = "RAM allouée à la VM en MB"
  type        = number
  default     = 1024
}

variable "vm_cores" {
  description = "Nombre de cœurs CPU"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 20
}

variable "vm_tags" {
  description = "Tags à appliquer aux VMs"
  type        = list(string)
  default     = ["nixos", "base"]
}

# ========================================
# Configuration Réseau
# ========================================

variable "network_bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip" {
  description = "Adresse IP de la première VM (format CIDR). VMs suivantes = IP+N"
  type        = string
  default     = "192.168.99.200/24"
}

variable "vm_gateway" {
  description = "Passerelle réseau"
  type        = string
  default     = "192.168.99.254"
}

variable "vm_nameserver" {
  description = "Serveur DNS"
  type        = string
  default     = "1.1.1.1"
}

# ========================================
# Configuration Utilisateur & SSH
# ========================================

variable "manager_user" {
  description = "Utilisateur cloud-init créé par Proxmox (--ciuser)"
  type        = string
  default     = "user"
}

variable "manager_ssh_public_key" {
  description = "Clé publique SSH pour l'utilisateur"
  type        = string
  sensitive   = true
  default     = "###SSH_KEY###"
}

# ========================================
# Configuration Système
# ========================================

variable "timezone" {
  description = "Timezone du système"
  type        = string
  default     = "Europe/Paris"
}
