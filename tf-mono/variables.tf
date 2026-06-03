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
  description = "Nom d'hôte"
  type        = string
  default     = "nixos-kube"
}

variable "vm_id" {
  description = "ID de base de la VM master (workers = vm_id + N)"
  type        = number
  default     = 1005
}

variable "nixos_image_file_id" {
  description = "ID Proxmox du qcow2 pré-uploadé (format: local:iso/nixos-kube.qcow2)"
  type        = string
  default     = "local:iso/nixos-kube.qcow2"
}

variable "vm_memory" {
  description = "RAM allouée à la VM en MB"
  type        = number
  default     = 4096
}

variable "vm_cores" {
  description = "Nombre de cœurs CPU"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 250
}

# ========================================
# Configuration Réseau
# ========================================

variable "network_bridge" {
  description = "Bridge réseau Proxmox"
  type        = string
  default     = "mgmt"
}

variable "vlan_nics" {
  description = "NICs VLAN sur vmbr1 — un NIC par VLAN, Proxmox pose le tag"
  type = list(object({
    bridge  = string
    vlan_id = number
    ip      = string
  }))
  default = []
}

variable "vm_ip" {
  description = "Adresse IP du master (format CIDR). Workers = IP+N"
  type        = string
  default     = "10.255.255.54/24"
}

variable "vm_gateway" {
  description = "Passerelle réseau"
  type        = string
  default     = "10.255.255.254"
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
# Kubernetes — provider
# ========================================

variable "kubeconfig_path" {
  description = "Chemin vers le kubeconfig généré par le module master"
  type        = string
  default     = "./output/kubeconfig"
}

# ========================================
# Module deployment — hello-world pods
# ========================================

variable "deployment_replicas" {
  description = "Nombre de replicas pour chaque déploiement"
  type        = number
  default     = 1
}

variable "deployment_nginx_image" {
  description = "Image Docker nginx utilisée par les pods hello-world"
  type        = string
  default     = "nginx:alpine"
}

variable "mario_external_ip" {
  description = "IP du VLAN pour le thème Mario 🍄 — VLAN dmz (sans le masque CIDR)"
  type        = string
  default     = "10.0.1.200"
}

variable "starwars_external_ip" {
  description = "IP du VLAN pour le thème Star Wars ⚔️ — VLAN perso (sans le masque CIDR)"
  type        = string
  default     = "10.0.5.200"
}

variable "matrix_external_ip" {
  description = "IP du VLAN pour le thème Matrix 💊 — VLAN ai (sans le masque CIDR)"
  type        = string
  default     = "10.0.10.200"
}
