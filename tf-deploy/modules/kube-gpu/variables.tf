# ════════════════════════════════════════════════════════════════
#  Module kube-gpu — Variables
#  AMD ROCm GPU Test on Kubernetes
# ════════════════════════════════════════════════════════════════

variable "namespace" {
  description = "Namespace Kubernetes dans lequel déployer le Job GPU"
  type        = string
}

variable "gpu_node_label_key" {
  description = "Clé du label Kubernetes qui identifie le node GPU AMD"
  type        = string
  default     = "gpu"
}

variable "gpu_node_label_value" {
  description = "Valeur du label Kubernetes qui identifie le node GPU AMD"
  type        = string
  default     = "amd"
}

variable "pytorch_rocm_image" {
  description = <<-EOD
    Image Docker pour le test GPU AMD.
    - rocm/rocm-terminal:latest  → ~2 GB  (ROCm tools + Python, sans PyTorch) ✅ défaut
    - rocm/pytorch:latest        → ~15 GB (PyTorch complet, nécessite >10 GB libres)
  EOD
  type    = string
  default = "rocm/rocm-terminal:latest"
}

variable "job_name" {
  description = "Nom du Job Kubernetes pour le test GPU"
  type        = string
  default     = "gpu-test-amd"
}

variable "backoff_limit" {
  description = "Nombre max de tentatives avant que le Job soit marqué Failed"
  type        = number
  default     = 2
}

variable "ttl_seconds_after_finished" {
  description = "Durée en secondes de conservation du Job après complétion (pour lire les logs)"
  type        = number
  default     = 600
}

variable "gpu_cpu_request" {
  description = "CPU request pour le container GPU"
  type        = string
  default     = "500m"
}

variable "gpu_cpu_limit" {
  description = "CPU limit pour le container GPU"
  type        = string
  default     = "2"
}

variable "gpu_memory_request" {
  description = "Memory request pour le container GPU"
  type        = string
  default     = "1Gi"
}

variable "gpu_memory_limit" {
  description = "Memory limit pour le container GPU"
  type        = string
  default     = "2Gi"
}

variable "amd_gpu_count" {
  description = "Nombre de GPUs AMD à allouer au container (resource amd.com/gpu)"
  type        = string
  default     = "1"
}

variable "amdgpu_device_plugin_image" {
  description = "Image Docker du AMD GPU device plugin pour Kubernetes"
  type        = string
  default     = "rocm/k8s-device-plugin:latest"
}

variable "gpu_node_name" {
  description = <<-EOD
    Nom exact du node Kubernetes portant le GPU AMD.
    Terraform y posera automatiquement le label gpu_node_label_key=gpu_node_label_value.
    Ex : "nixos-kube-worker-3"
    Laisser vide ("") pour ne pas gérer le label via Terraform.
  EOD
  type    = string
  default = ""
}
