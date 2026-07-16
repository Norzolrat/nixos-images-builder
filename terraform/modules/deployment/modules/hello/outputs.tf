output "external_ip" {
  value = var.external_ip
}

output "service_name" {
  value = kubernetes_service_v1.this.metadata[0].name
}
