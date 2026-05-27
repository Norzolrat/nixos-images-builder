# ════════════════════════════════════════════════════════════════
#  GPU Test — Appel du module kube-gpu  🎮
# ════════════════════════════════════════════════════════════════
#
# Ce fichier instancie le module ./modules/kube-gpu qui gère :
#   - ConfigMap  : script Python de test ROCm / PyTorch
#   - Job        : exécution du test sur le node GPU AMD
#
# Prérequis sur le node GPU (à faire UNE SEULE FOIS) :
#   kubectl --kubeconfig ../export/kubeconfig \
#     label node <nom-du-node-gpu> gpu=amd --overwrite
# ════════════════════════════════════════════════════════════════

module "kube_gpu" {
  source = "./modules/kube-gpu"

  # Namespace partagé avec les autres apps
  namespace = kubernetes_namespace_v1.hello_world.metadata[0].name

  # Sélection du node GPU
  gpu_node_label_key   = var.gpu_node_label_key
  gpu_node_label_value = var.gpu_node_label_value

  # Image Docker ROCm
  pytorch_rocm_image = var.pytorch_rocm_image

  # Nom du node GPU → Terraform pose le label gpu=amd automatiquement
  gpu_node_name = var.gpu_node_name

  # Ressources (valeurs par défaut du module sinon)
  # job_name                   = "gpu-test-amd"
  # backoff_limit               = 2
  # ttl_seconds_after_finished  = 600
  # amd_gpu_count               = "1"
  # gpu_cpu_request             = "500m"
  # gpu_cpu_limit               = "2"
  # gpu_memory_request          = "1Gi"
  # gpu_memory_limit            = "2Gi"
}
