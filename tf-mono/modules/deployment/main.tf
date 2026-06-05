# ════════════════════════════════════════
#  Sous-modules hello-world (namespace propre à chacun)
# ════════════════════════════════════════

module "mario" {
  source = "./modules/mario"

  namespace   = "hello-mario"
  replicas    = var.replicas
  nginx_image = var.nginx_image
  external_ip = var.mario_external_ip
}

module "starwars" {
  source = "./modules/starwars"

  namespace   = "hello-starwars"
  replicas    = var.replicas
  nginx_image = var.nginx_image
  external_ip = var.starwars_external_ip
}

module "matrix" {
  source = "./modules/matrix"

  namespace   = "hello-matrix"
  replicas    = var.replicas
  nginx_image = var.nginx_image
  external_ip = var.matrix_external_ip
}

module "cloudflare" {
  source = "./modules/cloudflare"

  namespace    = "cloudflare"
  tunnel_token = var.cloudflare_tunnel_token
  image        = var.cloudflared_image
}

module "traefik" {
  source = "./modules/traefik"

  namespace   = "traefik"
  dmz_vlan_ip = var.dmz_vlan_ip
}

module "perso" {
  source = "./modules/perso"

  namespace                = "perso"
  perso_vlan_ip            = var.perso_vlan_ip
  host_data_path           = var.perso_host_data_path
  postgres_password        = var.perso_postgres_password
  mariadb_password         = var.perso_mariadb_password
  passbolt_app_url         = var.perso_passbolt_app_url
  passbolt_gpg_fingerprint = var.perso_passbolt_gpg_fingerprint
  ghostfolio_secret        = var.perso_ghostfolio_secret
}

module "llm_stack" {
  source = "./modules/llm-stack"

  namespace          = "llm"
  ai_vlan_ip         = var.llm_ai_vlan_ip
  enable_comfyui     = var.llm_enable_comfyui
  enable_searxng     = var.llm_enable_searxng
  searxng_secret_key = var.llm_searxng_secret_key
  host_data_path     = var.llm_host_data_path
}
