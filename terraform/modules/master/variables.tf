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

variable "vm_disk_format" {
  description = "Format du disque VM — raw pour ZFS/LVM, qcow2 pour ext4/NFS"
  type        = string
  default     = "raw"
}

variable "vm_tags" {
  type    = list(string)
  default = ["nixos", "kubeadm", "master"]
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

variable "trunk_bridge" {
  description = "Bridge trunk Proxmox — passe tous les VLANs sans tag (eth1 dans la VM)"
  type        = string
  default     = "vmbr1"
}

variable "vlan_subinterfaces" {
  description = "Subinterfaces VLAN sur eth1 (trunk) — MetalLB L2"
  type = list(object({
    name    = string  # identifiant lisible (dmz, obs, perso, ai)
    vlan_id = number
    ip      = string  # CIDR ex: "10.0.1.200/24"
  }))
  default = []
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
