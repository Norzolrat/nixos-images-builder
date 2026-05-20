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
# Configuration SSH Proxmox
# ========================================

variable "proxmox_ssh_user" {
  description = "Utilisateur SSH sur le nœud Proxmox"
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
  description = "Nom d'hôte de la VM"
  type        = string
  default     = "nixos-amd-gpu"
}

variable "vm_id" {
  description = "ID de la VM dans Proxmox"
  type        = number
  default     = 8999
}

variable "nixos_image_file_id" {
  description = "ID Proxmox du qcow2 nixos-gpu-amd pré-uploadé"
  type        = string
  default     = "nixos-import:0/nixos-gpu-amd.qcow2"
}

variable "vm_memory" {
  description = "RAM allouée en MB"
  type        = number
  default     = 8192
}

variable "vm_cores" {
  description = "Nombre de cœurs CPU"
  type        = number
  default     = 4
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 40
}

variable "vm_tags" {
  description = "Tags Proxmox"
  type        = list(string)
  default     = ["nixos", "gpu", "amd"]
}

# ========================================
# Configuration GPU passthrough
# ========================================

variable "gpu_pci_mapping" {
  description = "Nom du resource mapping PCI déclaré dans Proxmox (Datacenter → Resource Mappings → PCI Devices)"
  type        = string
  default     = "amd-gpu"
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
  description = "Adresse IP de la VM (format CIDR)"
  type        = string
  default     = "192.168.99.210/24"
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
  description = "Utilisateur cloud-init"
  type        = string
  default     = "user"
}

variable "manager_ssh_public_key" {
  description = "Clé publique SSH"
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
