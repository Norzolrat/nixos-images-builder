terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.7"
    }
  }
}

locals {
  master_ip = split("/", var.vm_ip)[0]

  vlan_sub = [
    for idx, vlan in var.vlan_subinterfaces : {
      name        = vlan.name
      vlan_id     = vlan.vlan_id
      ip          = vlan.ip
      file_prefix = format("%02d", 20 + idx)
    }
  ]

  machine_nix = templatefile("${path.module}/templates/machine.nix.tpl", {
    vm_hostname        = var.vm_hostname
    timezone           = var.timezone
    vm_ip              = var.vm_ip
    vm_gateway         = var.vm_gateway
    vm_nameserver      = var.vm_nameserver
    vlan_subinterfaces = local.vlan_sub
  })

  # Fichiers NixOS sources — injectés sur la VM pour permettre nixos-rebuild switch
  configuration_nix_b64  = base64encode(file("${path.root}/../nix/configuration.nix"))
  k8s_nix_b64            = base64encode(file("${path.root}/../nix/k8s.nix"))
  gpu_amd_nix_b64        = base64encode(file("${path.root}/../nix/gpu-amd.nix"))
  hardware_image_nix_b64 = base64encode(file("${path.root}/../nix/hardware-image.nix"))
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
      vm_hostname           = var.vm_hostname
      timezone              = var.timezone
      pod_network_cidr      = var.pod_network_cidr
      calico_version        = var.calico_version
      vm_ip                 = var.vm_ip
      vm_gateway            = var.vm_gateway
      vm_nameserver         = var.vm_nameserver
      machine_nix_b64        = base64encode(local.machine_nix)
      configuration_nix_b64  = local.configuration_nix_b64
      k8s_nix_b64            = local.k8s_nix_b64
      gpu_amd_nix_b64        = local.gpu_amd_nix_b64
      hardware_image_nix_b64 = local.hardware_image_nix_b64
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
    type    = "x86-64-v3"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = var.vm_disk_format
    file_id      = var.nixos_image_file_id
  }

  efi_disk {
    datastore_id      = var.proxmox_storage
    pre_enrolled_keys = false
    type              = "4m"
  }

  # Passthrough PCIe — carte AMD via resource mapping Proxmox.
  # Désactivable (enable_gpu=false) pour contourner le reset bug AMD.
  dynamic "hostpci" {
    for_each = var.enable_gpu ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.gpu_pci_mapping
      pcie    = true
      rombar  = var.gpu_rombar
      xvga    = false
    }
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  network_device {
    bridge = var.trunk_bridge
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
