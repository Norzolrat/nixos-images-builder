terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.7"
    }
  }
}

# ========================================
# Upload du cloud-init custom sur Proxmox
# ========================================

resource "proxmox_virtual_environment_file" "cloud_init_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_snippets
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init-master.yml.tpl", {
      vm_hostname      = var.vm_hostname
      timezone         = var.timezone
      pod_network_cidr = var.pod_network_cidr
      calico_version   = var.calico_version
    })
    file_name = "cloud-init-kubeadm-master.yml"
  }
}

# ========================================
# VM kubeadm Master — clone du template NixOS
# ========================================

resource "proxmox_virtual_environment_vm" "master" {
  name      = var.vm_hostname
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  tags      = var.vm_tags

  description = "kubeadm Master - NixOS"

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
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = [var.vm_nameserver]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.cloud_init_config.id
  }

  depends_on = [proxmox_virtual_environment_file.cloud_init_config]
}
