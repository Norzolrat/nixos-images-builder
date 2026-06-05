output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "dmz_vlan_ip" {
  value = var.dmz_vlan_ip
}
