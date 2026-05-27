# ════════════════════════════════════════════════════════════════
#  Module kube-gpu — Outputs
# ════════════════════════════════════════════════════════════════

output "job_name" {
  description = "Nom du Job Kubernetes GPU créé"
  value       = kubernetes_job_v1.gpu_test.metadata[0].name
}

output "configmap_name" {
  description = "Nom du ConfigMap contenant le script GPU"
  value       = kubernetes_config_map_v1.gpu_test_script.metadata[0].name
}

output "namespace" {
  description = "Namespace dans lequel le Job GPU a été déployé"
  value       = var.namespace
}

output "image" {
  description = "Image Docker utilisée pour le test GPU"
  value       = var.pytorch_rocm_image
}

output "node_selector" {
  description = "Label de sélection du node GPU"
  value       = "${var.gpu_node_label_key}=${var.gpu_node_label_value}"
}

output "gpu_test_commands" {
  description = "Commandes kubectl pour suivre le test GPU"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║           GPU Test — AMD ROCm / PyTorch  🎮                   ║
    ╚════════════════════════════════════════════════════════════════╝

    Job       : ${kubernetes_job_v1.gpu_test.metadata[0].name}
    Namespace : ${var.namespace}
    Image     : ${var.pytorch_rocm_image}
    Node      : ${var.gpu_node_label_key}=${var.gpu_node_label_value}
    GPU alloc : amd.com/gpu = ${var.amd_gpu_count}

    AVANT le premier apply — labelliser le node GPU :
      kubectl --kubeconfig ../export/kubeconfig \
        label node <nom-node-gpu> ${var.gpu_node_label_key}=${var.gpu_node_label_value} --overwrite

    Vérifier device plugin AMD :
      kubectl --kubeconfig ../export/kubeconfig get nodes \
        -o custom-columns="NODE:.metadata.name,GPU:.status.capacity.amd\.com/gpu"

    Statut du Job :
      kubectl --kubeconfig ../export/kubeconfig \
        -n ${var.namespace} get job ${kubernetes_job_v1.gpu_test.metadata[0].name}

    Suivre les logs en live :
      kubectl --kubeconfig ../export/kubeconfig \
        -n ${var.namespace} logs -l app=gpu-test -f

    Relancer le test (supprimer + re-apply) :
      kubectl --kubeconfig ../export/kubeconfig \
        -n ${var.namespace} delete job ${kubernetes_job_v1.gpu_test.metadata[0].name}
      terraform apply -target=module.kube_gpu

  EOT
}
