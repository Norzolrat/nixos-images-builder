locals {
  # Dériver l'IP seule (sans masque) et le nom de l'interface subinterface
  pools = {
    for vlan in var.vlan_subinterfaces : vlan.name => {
      name      = vlan.name
      cidr      = "${split("/", vlan.ip)[0]}/32"
      interface = "eth1.${vlan.vlan_id}"
    }
  }
}

# ========================================
# MetalLB — installation via Helm
# ========================================

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.metallb_version
  namespace        = "metallb-system"
  create_namespace = true

  wait          = true
  wait_for_jobs = true
  timeout       = 300
}

# ========================================
# IPAddressPool — une pool par VLAN
# ========================================

resource "kubernetes_manifest" "ip_pool" {
  for_each = local.pools

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = each.key
      namespace = "metallb-system"
    }
    spec = {
      addresses = [each.value.cidr]
    }
  }

  depends_on = [helm_release.metallb]
}

# ========================================
# L2Advertisement — une par VLAN, liée à la subinterface
# ========================================

resource "kubernetes_manifest" "l2_advert" {
  for_each = local.pools

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = each.key
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = [each.key]
      interfaces     = [each.value.interface]
    }
  }

  depends_on = [kubernetes_manifest.ip_pool]
}
