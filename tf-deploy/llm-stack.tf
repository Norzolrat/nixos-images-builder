# ════════════════════════════════════════════════════════════════
#  LLM Stack — Appel du module llm-stack  🤖
# ════════════════════════════════════════════════════════════════
#
#  Déploie sur le cluster Kubernetes :
#    🦙 Ollama      — inference LLM (AMD ROCm)      :30434
#    🎨 ComfyUI     — Stable Diffusion (AMD ROCm)   :30188
#    🌐 Open-WebUI  — interface unifiée chat+images :30300
#    🔍 SearXNG     — moteur de recherche privé     :30810
#
#  Toutes les données persistent dans /opt/llm/ sur nixos-kube-worker-3
# ════════════════════════════════════════════════════════════════

module "llm_stack" {
  source = "./modules/llm-stack"

  # Node GPU AMD
  gpu_node_label_key   = var.gpu_node_label_key
  gpu_node_label_value = var.gpu_node_label_value

  # Clé secrète SearXNG
  searxng_secret_key = var.searxng_secret_key

  # Valeurs par défaut du module utilisées pour le reste :
  # namespace            = "llm"
  # host_data_path       = "/opt/llm"
  # ollama_node_port     = 30434
  # comfyui_node_port    = 30188
  # open_webui_node_port = 30300
  # searxng_node_port    = 30810
  # render_group_id      = 993
  # video_group_id       = 44
}
