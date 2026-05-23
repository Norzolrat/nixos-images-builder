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
# Récupération du kubeconfig
# ========================================

resource "null_resource" "fetch_kubeconfig" {
  triggers = {
    master_ip = local.master_ip
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Attente du kubeconfig sur ${var.manager_user}@${local.master_ip}..."
      for i in $(seq 1 40); do
        if scp -o StrictHostKeyChecking=no \
               -o ConnectTimeout=10 \
               -i ${var.ssh_private_key_path} \
               ${var.manager_user}@${local.master_ip}:~/kubeconfig \
               ../export/kubeconfig 2>/dev/null; then
          echo "kubeconfig recupere avec succes -> ../export/kubeconfig"
          exit 0
        fi
        echo "Tentative $i/40 echouee - nouvelle tentative dans 30s..."
        sleep 30
      done
      echo "Impossible de recuperer le kubeconfig apres 20 minutes"
      exit 1
    EOT
  }

  depends_on = [
    module.master,
    null_resource.ssh_known_hosts_master,
  ]
}

# ========================================
# Récupération du join-command depuis le master
# Disponible dès que kubeadm init + Calico sont terminés
# ========================================

resource "null_resource" "fetch_join_command" {
  triggers = {
    master_ip = local.master_ip
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Génération d'un join-command via SSH sur ${local.master_ip}..."
      JOIN_CMD=$(ssh -o StrictHostKeyChecking=no \
                     -o ConnectTimeout=10 \
                     -i ${var.ssh_private_key_path} \
                     ${var.manager_user}@${local.master_ip} \
                     "sudo /run/current-system/sw/bin/kubeadm token create --print-join-command 2>/dev/null")
      if [ -z "$JOIN_CMD" ]; then
        echo "ERREUR : join-command vide"
        exit 1
      fi
      printf '#!/run/current-system/sw/bin/bash\nexport PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH\n%s\n' "$JOIN_CMD" > ../export/kubeadm-join.sh
      chmod 700 ../export/kubeadm-join.sh
      echo "join-command sauvegardé -> ../export/kubeadm-join.sh"
      cat ../export/kubeadm-join.sh
    EOT
  }

  depends_on = [null_resource.fetch_kubeconfig]
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
# Join des workers normaux via Terraform remote-exec
# ========================================

resource "null_resource" "join_workers" {
  count = var.worker_count

  triggers = {
    worker_ip        = local.worker_ips[count.index]
    join_command_id  = null_resource.fetch_join_command.id
  }

  provisioner "file" {
    source      = "../export/kubeadm-join.sh"
    destination = "/tmp/kubeadm-join.sh"

    connection {
      type        = "ssh"
      host        = local.worker_ips[count.index]
      user        = var.manager_user
      private_key = file(pathexpand(var.ssh_private_key_path))
      timeout     = "10m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "while ! systemctl is-active --quiet containerd; do echo 'Attente containerd...'; sleep 5; done",
      "sudo bash /tmp/kubeadm-join.sh 2>&1 | tee /tmp/kubeadm-join.log",
    ]

    connection {
      type        = "ssh"
      host        = local.worker_ips[count.index]
      user        = var.manager_user
      private_key = file(pathexpand(var.ssh_private_key_path))
      timeout     = "10m"
    }
  }

  depends_on = [
    module.worker,
    null_resource.fetch_join_command,
    null_resource.ssh_known_hosts_workers,
  ]
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

# ========================================
# Join des workers GPU AMD via Terraform remote-exec
# ========================================

resource "null_resource" "join_gpu_workers" {
  count = var.gpu_worker_count

  triggers = {
    worker_ip       = local.gpu_worker_ips[count.index]
    join_command_id = null_resource.fetch_join_command.id
  }

  provisioner "file" {
    source      = "../export/kubeadm-join.sh"
    destination = "/tmp/kubeadm-join.sh"

    connection {
      type        = "ssh"
      host        = local.gpu_worker_ips[count.index]
      user        = var.manager_user
      private_key = file(pathexpand(var.ssh_private_key_path))
      timeout     = "15m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "while ! systemctl is-active --quiet containerd; do echo 'Attente containerd...'; sleep 5; done",
      "sudo bash /tmp/kubeadm-join.sh 2>&1 | tee /tmp/kubeadm-join.log",
    ]

    connection {
      type        = "ssh"
      host        = local.gpu_worker_ips[count.index]
      user        = var.manager_user
      private_key = file(pathexpand(var.ssh_private_key_path))
      timeout     = "15m"
    }
  }

  depends_on = [
    module.worker_gpu_amd,
    null_resource.fetch_join_command,
    null_resource.ssh_known_hosts_workers_gpu,
  ]
}
