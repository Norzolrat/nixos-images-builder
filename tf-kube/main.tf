locals {
  master_ip = split("/", var.vm_ip)[0]

  # Workers normaux : master+1, master+2, ...
  worker_ips = [for i in range(var.worker_count) : format(
    "%s.%s.%s.%d",
    split(".", split("/", var.vm_ip)[0])[0],
    split(".", split("/", var.vm_ip)[0])[1],
    split(".", split("/", var.vm_ip)[0])[2],
    tonumber(split(".", split("/", var.vm_ip)[0])[3]) + i + 1
  )]

  # Workers GPU : succèdent aux workers normaux
  gpu_worker_ips = [for i in range(var.gpu_worker_count) : format(
    "%s.%s.%s.%d",
    split(".", split("/", var.vm_ip)[0])[0],
    split(".", split("/", var.vm_ip)[0])[1],
    split(".", split("/", var.vm_ip)[0])[2],
    tonumber(split(".", split("/", var.vm_ip)[0])[3]) + var.worker_count + i + 1
  )]
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

resource "null_resource" "ssh_known_hosts_workers" {
  count = var.worker_count

  triggers = {
    vm_id = var.vm_id + count.index + 1
    vm_ip = local.worker_ips[count.index]
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${local.worker_ips[count.index]} || true"
  }

  depends_on = [module.worker]
}

resource "null_resource" "ssh_known_hosts_workers_gpu" {
  count = var.gpu_worker_count

  triggers = {
    vm_id = var.vm_id + var.worker_count + count.index + 1
    vm_ip = local.gpu_worker_ips[count.index]
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${local.gpu_worker_ips[count.index]} || true"
  }

  depends_on = [module.worker_gpu_amd]
}

# ========================================
# Module kubeadm Master
# ========================================

module "master" {
  source = "./modules/master"

  proxmox_node               = var.proxmox_node
  proxmox_storage            = var.proxmox_storage
  proxmox_datastore_snippets = var.proxmox_datastore_snippets

  vm_hostname          = "${var.vm_hostname}-master"
  vm_id                = var.vm_id
  nixos_image_file_id  = var.nixos_image_file_id
  vm_memory            = var.vm_memory
  vm_cores             = var.vm_cores
  vm_disk_size         = var.vm_disk_size
  vm_tags              = concat(var.vm_tags, ["master"])

  network_bridge = var.network_bridge
  vm_ip          = var.vm_ip
  vm_gateway     = var.vm_gateway
  vm_nameserver  = var.vm_nameserver

  pod_network_cidr = var.pod_network_cidr
  calico_version   = var.calico_version

  manager_user           = var.manager_user
  manager_ssh_public_key = var.manager_ssh_public_key
  ssh_private_key_path   = var.ssh_private_key_path

  timezone = var.timezone
}

# ========================================
# Module kubeadm Workers (avec count)
# ========================================

module "worker" {
  count  = var.worker_count
  source = "./modules/worker"

  proxmox_node               = var.proxmox_node
  proxmox_storage            = var.proxmox_storage
  proxmox_datastore_snippets = var.proxmox_datastore_snippets

  vm_hostname         = "${var.vm_hostname}-worker-${count.index + 1}"
  vm_id               = var.vm_id + count.index + 1
  nixos_image_file_id = var.nixos_image_file_id
  vm_memory           = var.vm_memory
  vm_cores            = var.vm_cores
  vm_disk_size        = var.vm_disk_size
  vm_tags             = concat(var.vm_tags, ["worker"])

  vm_ip = format(
    "%s.%s.%s.%d/%s",
    split(".", split("/", var.vm_ip)[0])[0],
    split(".", split("/", var.vm_ip)[0])[1],
    split(".", split("/", var.vm_ip)[0])[2],
    tonumber(split(".", split("/", var.vm_ip)[0])[3]) + count.index + 1,
    split("/", var.vm_ip)[1]
  )
  vm_gateway     = var.vm_gateway
  vm_nameserver  = var.vm_nameserver
  network_bridge = var.network_bridge

  master_ip = local.master_ip

  manager_user           = var.manager_user
  manager_ssh_public_key = var.manager_ssh_public_key
  ssh_private_key_path   = var.ssh_private_key_path

  timezone = var.timezone

  extra_nic_enabled = var.worker_extra_nic_enabled
  extra_nic_bridge  = var.worker_extra_nic_bridge

  depends_on = [module.master]
}

# ========================================
# Module kubeadm Workers GPU AMD (avec count)
# Numérotés à la suite des workers normaux
# ========================================

module "worker_gpu_amd" {
  count  = var.gpu_worker_count
  source = "./modules/worker-gpu-amd"

  proxmox_node               = var.proxmox_node
  proxmox_storage            = var.proxmox_storage
  proxmox_datastore_snippets = var.proxmox_datastore_snippets

  vm_hostname         = "${var.vm_hostname}-worker-${var.worker_count + count.index + 1}"
  vm_id               = var.vm_id + var.worker_count + count.index + 1
  nixos_image_file_id = var.gpu_worker_nixos_image_file_id
  vm_memory           = var.gpu_worker_memory
  vm_cores            = var.gpu_worker_cores
  vm_disk_size        = var.gpu_worker_disk_size
  vm_tags             = concat(var.vm_tags, ["worker", "gpu", "amd"])

  vm_ip = format(
    "%s.%s.%s.%d/%s",
    split(".", split("/", var.vm_ip)[0])[0],
    split(".", split("/", var.vm_ip)[0])[1],
    split(".", split("/", var.vm_ip)[0])[2],
    tonumber(split(".", split("/", var.vm_ip)[0])[3]) + var.worker_count + count.index + 1,
    split("/", var.vm_ip)[1]
  )
  vm_gateway     = var.vm_gateway
  vm_nameserver  = var.vm_nameserver
  network_bridge = var.network_bridge

  gpu_pci_mapping = var.gpu_pci_mapping
  master_ip       = local.master_ip

  manager_user           = var.manager_user
  manager_ssh_public_key = var.manager_ssh_public_key
  ssh_private_key_path   = var.ssh_private_key_path

  timezone = var.timezone

  depends_on = [module.master]
}
