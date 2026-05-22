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
  description = "Préfixe du nom d'hôte (master = <hostname>-master, worker = <hostname>-worker-N)"
  type        = string
  default     = "nixos-kube"
}

variable "vm_id" {
  description = "ID de base de la VM master (workers = vm_id + N)"
  type        = number
  default     = 10001
}

variable "nixos_image_file_id" {
  description = "ID Proxmox du qcow2 pré-uploadé (format: local:iso/nixos-kube.qcow2)"
  type        = string
  default     = "local:iso/nixos-kube.qcow2"
}

variable "vm_memory" {
  description = "RAM allouée à la VM en MB"
  type        = number
  default     = 2048
}

variable "vm_cores" {
  description = "Nombre de cœurs CPU"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 50
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
  description = "Adresse IP du master (format CIDR). Workers = IP+N"
  type        = string
  default     = "192.168.99.186/24"
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

variable "vm_tags" {
  description = "Tags à appliquer aux VMs"
  type        = list(string)
  default     = ["nixos", "kubeadm"]
}

# ========================================
# Configuration kubeadm
# ========================================

variable "pod_network_cidr" {
  description = "Range réseau pour les pods (kubeadm --pod-network-cidr)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "calico_version" {
  description = "Version de Calico CNI à installer"
  type        = string
  default     = "3.29.3"
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

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH pour le provisioning Terraform"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# ========================================
# Configuration Système
# ========================================

variable "timezone" {
  description = "Timezone du système"
  type        = string
  default     = "Europe/Paris"
}

# ========================================
# Configuration Workers
# ========================================

variable "worker_count" {
  description = "Nombre de workers kubeadm à déployer"
  type        = number
  default     = 2
}

variable "worker_extra_nic_enabled" {
  description = "Activer une seconde carte réseau sur les workers (désactivée par défaut, à configurer manuellement)"
  type        = bool
  default     = false
}

variable "worker_extra_nic_bridge" {
  description = "Bridge Proxmox utilisé pour la seconde carte réseau des workers"
  type        = string
  default     = "vmbr1"
}

# ========================================
# Configuration Workers GPU AMD
# ========================================

variable "gpu_worker_count" {
  description = "Nombre de workers GPU à déployer (numérotés à la suite des workers normaux)"
  type        = number
  default     = 0
}

variable "gpu_worker_nixos_image_file_id" {
  description = "ID Proxmox du qcow2 nixos-k8s-gpu-amd uploadé"
  type        = string
  default     = "nixos-import:0/nixos-k8s-gpu-amd.qcow2"
}

variable "gpu_worker_memory" {
  description = "RAM allouée aux workers GPU en MB"
  type        = number
  default     = 8192
}

variable "gpu_worker_cores" {
  description = "Nombre de cœurs CPU pour les workers GPU"
  type        = number
  default     = 4
}

variable "gpu_worker_disk_size" {
  description = "Taille du disque des workers GPU en GB"
  type        = number
  default     = 40
}

variable "gpu_pci_mapping" {
  description = "Nom du resource mapping PCI AMD déclaré dans Proxmox (Datacenter → Resource Mappings → PCI Devices)"
  type        = string
  default     = "amd-gpu"
}
