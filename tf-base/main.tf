locals {
  # Calcule la liste d'IPs : première VM = vm_ip, suivantes = IP+N
  vm_ips = [for i in range(var.vm_count) : format(
    "%s.%s.%s.%d/%s",
    split(".", split("/", var.vm_ip)[0])[0],
    split(".", split("/", var.vm_ip)[0])[1],
    split(".", split("/", var.vm_ip)[0])[2],
    tonumber(split(".", split("/", var.vm_ip)[0])[3]) + i,
    split("/", var.vm_ip)[1]
  )]

  # Hostname : si une seule VM → vm_hostname, sinon vm_hostname-1, vm_hostname-2, ...
  vm_hostnames = [for i in range(var.vm_count) :
    var.vm_count == 1 ? var.vm_hostname : "${var.vm_hostname}-${i + 1}"
  ]
}

# ========================================
# Nettoyage known_hosts local à chaque redéploiement
# ========================================

resource "null_resource" "ssh_known_hosts" {
  count = var.vm_count

  triggers = {
    vm_id = var.vm_id + count.index
    vm_ip = split("/", local.vm_ips[count.index])[0]
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${split("/", local.vm_ips[count.index])[0]} || true"
  }

  depends_on = [proxmox_virtual_environment_vm.base]
}

# ========================================
# Snippet cloud-init par VM
# ========================================

resource "proxmox_virtual_environment_file" "cloud_init_config" {
  count        = var.vm_count
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_snippets
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      vm_hostname  = local.vm_hostnames[count.index]
      timezone     = var.timezone
      manager_user = var.manager_user
    })
    file_name = "cloud-init-base-${local.vm_hostnames[count.index]}.yml"
  }
}

# ========================================
# VM NixOS base — clone du template
# ========================================

resource "proxmox_virtual_environment_vm" "base" {
  count     = var.vm_count
  name      = local.vm_hostnames[count.index]
  node_name = var.proxmox_node
  vm_id     = var.vm_id + count.index
  tags      = var.vm_tags

  description = "NixOS base VM"

  on_boot = true
  started = true

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  memory {
    dedicated = var.vm_memory
  }

  cpu {
    cores   = var.vm_cores
    sockets = 1
    type    = "host"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = "qcow2"
    file_id      = var.nixos_image_file_id
  }

  efi_disk {
    datastore_id      = var.proxmox_storage
    pre_enrolled_keys = false
    type              = "4m"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  serial_device {}

  initialization {
    datastore_id = var.proxmox_storage

    user_account {
      username = var.manager_user
      keys     = [var.manager_ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = local.vm_ips[count.index]
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = [var.vm_nameserver]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.cloud_init_config[count.index].id
  }

  depends_on = [proxmox_virtual_environment_file.cloud_init_config]
}
