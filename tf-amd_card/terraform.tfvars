# ========================================
# Configuration Proxmox
# ========================================

proxmox_api_url              = "https://10.255.255.250:8006/api2/json"
proxmox_user                 = "terraform@pve"
proxmox_token_name           = "terraform"
proxmox_token                = "1c2e6b41-e6d1-4d2a-9d4b-79349f42b1eb"
proxmox_ssh_user             = "root"
proxmox_ssh_private_key_path = "~/.ssh/id_ed25519_terraform"
proxmox_node                 = "pve"
proxmox_storage              = "vm-pool"
proxmox_datastore_snippets   = "local"

# ========================================
# Configuration VM
# ========================================

vm_hostname         = "nixos-amd-gpu"
vm_id               = 8999
nixos_image_file_id = "nixos-import:0/nixos-gpu-amd.qcow2"
vm_memory           = 8192
vm_cores            = 4
vm_disk_size        = 40
vm_tags             = ["nixos", "gpu", "amd"]

# ========================================
# Configuration GPU passthrough
# ========================================

# Nom du resource mapping à créer dans Proxmox :
#   Datacenter → Resource Mappings → PCI Devices → Add
#   Name: "amd-gpu"  |  Node: pve  |  PCI ID: 0000:c0:00
# Permission à donner à terraform@pve :
#   Datacenter → Permissions → Add
#   User: terraform@pve  |  Path: /mapping/pci/amd-gpu  |  Role: PVEMappingUser
gpu_pci_mapping = "amd-gpu"

# ========================================
# Configuration Réseau
# ========================================

network_bridge = "vmbr0"
vm_ip          = "192.168.99.210/24"
vm_gateway     = "192.168.99.254"
vm_nameserver  = "1.1.1.1"

# ========================================
# Configuration Utilisateur & SSH
# ========================================

manager_user           = "user"
manager_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERSYZPHToJoNNn+TpLLVn0FPgcaUhO/5uJOresMwX6J manager@tools-box"

# ========================================
# Configuration Système
# ========================================

timezone = "Europe/Paris"
