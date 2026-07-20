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

variable "vm_disk_format" {
  description = "Format du disque VM — raw pour ZFS/LVM, qcow2 pour ext4/NFS"
  type        = string
  default     = "raw"
}

# ========================================
# Configuration Réseau
# ========================================

variable "network_bridge" {
  description = "Bridge réseau Proxmox pour le management (eth0)"
  type        = string
  default     = "mgmt"
}

variable "trunk_bridge" {
  description = "Bridge trunk Proxmox — passe tous les VLANs sans tag (eth1 dans la VM)"
  type        = string
  default     = "vmbr1"
}

variable "vlan_subinterfaces" {
  description = "Subinterfaces VLAN sur eth1 — MetalLB L2 (name, vlan_id, ip en CIDR)"
  type = list(object({
    name    = string
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
# GPU passthrough (master)
# ========================================

variable "enable_gpu_passthrough" {
  description = "Attacher le GPU AMD en passthrough. Mettre à false pour déployer sans GPU (ex: carte wedgée par le reset bug — la VM boote alors normalement)"
  type        = bool
  default     = true
}

variable "gpu_pci_mapping" {
  description = "Nom du resource mapping PCI déclaré dans Proxmox (Datacenter → Resource Mappings → PCI Devices)"
  type        = string
  default     = "amd-gpu"
}

variable "gpu_rombar" {
  description = "Exposer la ROM du GPU au firmware (rombar). false = OVMF n'exécute pas la vBIOS au boot — évite le gel UEFI quand la carte sort d'un reset raté"
  type        = bool
  default     = false
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

# ========================================
# Cloudflare Tunnel
# ========================================

variable "cloudflare_tunnel_token" {
  description = "Token du tunnel Cloudflare (Zero Trust > Networks > Tunnels > Configure > Token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflared_image" {
  type    = string
  default = "cloudflare/cloudflared:latest"
}

# ========================================
# Traefik (VLAN dmz)
# ========================================

variable "vlan1_external_ip" {
  description = "IP du VLAN dmz pour Traefik (ports 80 et 443)"
  type        = string
  default     = "10.0.15.200"
}

variable "traefik_mgmt_ip" {
  description = "IP management du nœud kube — cible NAT SNS firewall"
  type        = string
  default     = "10.255.255.54"
}

variable "traefik_cloudflare_api_token" {
  description = "Token Cloudflare DNS pour ACME Let's Encrypt (permission Zone:DNS:Edit)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "traefik_acme_host_data_path" {
  description = "Chemin persistance acme.json sur le nœud hôte"
  type        = string
  default     = "/opt/traefik-acme"
}

variable "traefik_dashboard_htpasswd" {
  description = "Credentials dashboard Traefik au format htpasswd (générer avec : htpasswd -nB user password)"
  type        = string
  sensitive   = true
}

variable "vlan5_external_ip" {
  description = "IP du VLAN pour le thème Star Wars ⚔️ — VLAN perso (sans le masque CIDR)"
  type        = string
  default     = "10.0.5.200"
}

variable "vlan10_external_ip" {
  description = "IP du VLAN pour le thème Matrix 💊 — VLAN ai (sans le masque CIDR)"
  type        = string
  default     = "10.0.10.200"
}

# ========================================
# Management — Teleport
# ========================================

variable "teleport_vlan_ip" {
  description = "IP exposée pour Teleport sur le VLAN management"
  type        = string
  default     = "10.255.255.251"
}

variable "teleport_host_data_path" {
  description = "Chemin persistance Teleport sur le nœud hôte"
  type        = string
  default     = "/opt/teleport"
}

variable "coder_postgres_password" {
  type      = string
  sensitive = true
  default   = "changeme-replace-with-secure-password"
}

variable "coder_access_url" {
  type    = string
  default = "https://coder.magnaloca.com"
}

variable "coder_wildcard_access_url" {
  type    = string
  default = "*--apps.coder.magnaloca.com"
}

variable "coder_host_data_path" {
  type    = string
  default = "/opt/coder-postgres"
}

# ========================================
# Perso Stack (Passbolt · Affine · NextExplorer · Ghostfolio)
# ========================================

variable "perso_vlan_ip" {
  description = "IP du VLAN perso (Passbolt · Affine · NextExplorer · Ghostfolio)"
  type        = string
  default     = "10.0.5.200"
}

variable "perso_host_data_path" {
  type    = string
  default = "/opt/perso"
}

variable "perso_postgres_password" {
  type      = string
  sensitive = true
  default   = "changeme"
}

variable "perso_passbolt_app_url" {
  type    = string
  default = "http://10.0.5.200:8080"
}

variable "perso_passbolt_gpg_fingerprint" {
  type = string
}

variable "perso_passbolt_gpg_public_key" {
  type = string
}

variable "perso_passbolt_gpg_private_key" {
  type      = string
  sensitive = true
}

variable "perso_ghostfolio_secret" {
  type      = string
  sensitive = true
  default   = "changeme-replace-with-random-secret"
}

# ========================================
# LLM Stack (Ollama · Open-WebUI · ComfyUI · SearXNG)
# ========================================

variable "llm_ai_vlan_ip" {
  description = "IP du VLAN ai pour les APIs LLM (défaut : même IP que le VLAN ai)"
  type        = string
  default     = "10.0.10.200"
}

variable "llm_enable_comfyui" {
  description = "Déployer ComfyUI (Stable Diffusion)"
  type        = bool
  default     = false
}

variable "llm_enable_searxng" {
  description = "Déployer SearXNG (moteur de recherche privé)"
  type        = bool
  default     = false
}

variable "llm_searxng_secret_key" {
  description = "Clé secrète SearXNG (générer avec : openssl rand -hex 32)"
  type        = string
  sensitive   = true
  default     = "changeme-replace-with-random-secret"
}

variable "llm_host_data_path" {
  description = "Chemin de base sur le node pour les données LLM persistantes"
  type        = string
  default     = "/opt/llm"
}
