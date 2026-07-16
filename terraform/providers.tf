terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_user}!${var.proxmox_token_name}=${var.proxmox_token}"
  insecure  = true

  ssh {
    agent       = false
    username    = var.proxmox_ssh_user
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
  insecure    = true
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
    insecure    = true
  }
}