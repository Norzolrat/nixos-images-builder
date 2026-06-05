locals {
  master_ip = split("/", var.vm_ip)[0]
}

# ========================================
# Nettoyage known_hosts local à chaque redéploiement
# ========================================

resource "null_resource" "ssh_known_hosts_master" {
  triggers = {
    vm_id = var.vm_id
    vm_ip = local.master_ip
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${local.master_ip} || true"
  }

  depends_on = [module.master]
}


# ========================================
# Module kubeadm Master
# ========================================

module "master" {
  source = "./modules/master"

  proxmox_node               = var.proxmox_node
  proxmox_storage            = var.proxmox_storage
  proxmox_datastore_snippets = var.proxmox_datastore_snippets

  vm_hostname         = var.vm_hostname
  vm_id               = var.vm_id
  nixos_image_file_id = var.nixos_image_file_id
  vm_memory           = var.vm_memory
  vm_cores            = var.vm_cores
  vm_disk_size        = var.vm_disk_size
  vm_tags             = concat(var.vm_tags, ["master"])

  network_bridge = var.network_bridge
  vlan_nics      = var.vlan_nics
  vm_ip          = var.vm_ip
  vm_gateway     = var.vm_gateway
  vm_nameserver  = var.vm_nameserver

  pod_network_cidr = var.pod_network_cidr
  calico_version   = var.calico_version

  gpu_pci_mapping = var.gpu_pci_mapping

  manager_user           = var.manager_user
  manager_ssh_public_key = var.manager_ssh_public_key
  ssh_private_key_path   = var.ssh_private_key_path

  timezone = var.timezone
}

# ========================================
# Attente fin du cloud-init (SSH dispo + bootstrap terminé)
# ========================================

resource "null_resource" "wait_cloud_init" {
  triggers = {
    vm_id = module.master.vm_id
  }

  connection {
    type        = "ssh"
    host        = local.master_ip
    user        = var.manager_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "while [ ! -f ~/kubeconfig ]; do sleep 10; done",
    ]
  }

  depends_on = [
    module.master,
    null_resource.ssh_known_hosts_master,
  ]
}

# ========================================
# Récupération du kubeconfig
# ========================================

resource "null_resource" "fetch_kubeconfig" {
  triggers = {
    vm_id = module.master.vm_id
  }

  provisioner "local-exec" {
    command = "mkdir -p ./output && scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.manager_user}@${local.master_ip}:~/kubeconfig ./output/kubeconfig"
  }

  depends_on = [null_resource.wait_cloud_init]
}

# ========================================
# Attente que l'API Kubernetes soit prête
# (le provider K8s s'initialise au démarrage du apply —
#  sans ce check, la passe 2 peut tomber sur Unauthorized
#  si l'API server n'a pas encore fini de démarrer)
# ========================================

resource "null_resource" "wait_kubernetes_ready" {
  triggers = {
    vm_id = module.master.vm_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Attente que l'API Kubernetes soit prête..."
      for i in $(seq 1 36); do
        if kubectl --kubeconfig ./output/kubeconfig --insecure-skip-tls-verify get nodes >/dev/null 2>&1; then
          echo "API Kubernetes prête !"
          exit 0
        fi
        echo "Tentative $i/36 — pas encore prête, attente 10s..."
        sleep 10
      done
      echo "Timeout : API Kubernetes pas prête après 6 min"
      exit 1
    EOT
  }

  depends_on = [null_resource.fetch_kubeconfig]
}


# ========================================
# Module deployment — hello-world pods
# ========================================

module "deployment" {
  source = "./modules/deployment"

  replicas             = var.deployment_replicas
  nginx_image          = var.deployment_nginx_image
  mario_external_ip    = var.mario_external_ip
  starwars_external_ip = var.starwars_external_ip
  matrix_external_ip   = var.matrix_external_ip

  cloudflare_tunnel_token = var.cloudflare_tunnel_token
  cloudflared_image       = var.cloudflared_image
  dmz_vlan_ip             = var.dmz_vlan_ip

  llm_ai_vlan_ip         = var.llm_ai_vlan_ip
  llm_enable_comfyui     = var.llm_enable_comfyui
  llm_enable_searxng     = var.llm_enable_searxng
  llm_searxng_secret_key = var.llm_searxng_secret_key
  llm_host_data_path     = var.llm_host_data_path

  depends_on = [null_resource.wait_kubernetes_ready]
}
