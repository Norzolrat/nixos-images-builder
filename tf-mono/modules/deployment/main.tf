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
