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
  default = "kubeadm-worker-gpu-01"
}

variable "vm_id" {
  type    = number
  default = 9004
}

variable "nixos_image_file_id" {
  description = "ID du qcow2 nixos-k8s-gpu-amd uploadé sur Proxmox"
  type        = string
}

variable "vm_memory" {
  type    = number
  default = 8192
}

variable "vm_cores" {
  type    = number
  default = 4
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 40
}

variable "vm_tags" {
  type    = list(string)
  default = ["nixos", "kubeadm", "worker", "gpu", "amd"]
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

variable "master_ip" {
  description = "IP du master (pour récupérer le join-command)"
  type        = string
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
