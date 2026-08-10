.PHONY: build-k8s-gpu-amd upload-k8s-gpu-amd prepare-template deploy-init deploy-plan deploy deploy-cluster deploy-module deploy-module-destroy deploy-list deploy-destroy status help

# `make` sans argument affiche l'aide plutôt que de lancer un build.
.DEFAULT_GOAL := help

# Les lignes "#>" ci-dessous alimentent la section Variables de `make help`.
# Format : #> NOM<au moins 2 espaces>description
#> PROXMOX_SSH       Destination scp <user>@<machine> (défaut: root@pve)
#> PROXMOX_SSH_USER  User SSH Proxmox si PROXMOX_SSH non fourni (défaut: root)
#> PROXMOX_HOST      Hôte Proxmox si PROXMOX_SSH non fourni (défaut: pve)
#> PROXMOX_IMAGE_DIR Répertoire de dépôt du qcow2 (défaut: /var/lib/vz/import/images/0)
#> SSH_KEY           Clé SSH Proxmox/template (défaut: ~/.ssh/id_ed25519_terraform)
#> TEMPLATE_IP       IP de la VM template (requis pour prepare-template)
#> TEMPLATE_USER     User SSH template (défaut: user)
#> EXPORT_DIR        Répertoire de sortie des images (défaut: ./export)
#> TF_DIR            Racine Terraform (défaut: ./terraform)
#> GPU               true|false — passthrough GPU (défaut: valeur tfvars)
#> CLOUDFLARE_TOKEN  Token tunnel Cloudflare (optionnel)
#> MODULE            Module deployment ciblé (deploy-module, deploy-module-destroy)

TEMPLATE_IP   ?=
TEMPLATE_USER ?= user
SSH_KEY       ?= ~/.ssh/id_ed25519_terraform

# Destination de l'upload. PROXMOX_SSH se surcharge d'un bloc :
#   make upload-k8s-gpu-amd PROXMOX_SSH=nico@192.168.1.50
# ou pièce par pièce (PROXMOX_SSH_USER / PROXMOX_HOST).
# NB: ne pas y mettre l'utilisateur API Proxmox (root@pam) — c'est un
# utilisateur SSH qui est attendu ici, le realm @pam ferait échouer le scp.
PROXMOX_SSH_USER  ?= root
PROXMOX_HOST      ?= pve
PROXMOX_SSH       ?= $(PROXMOX_SSH_USER)@$(PROXMOX_HOST)
PROXMOX_IMAGE_DIR ?= /var/lib/vz/import/images/0

EXPORT_DIR = ./export
TF_DIR     = ./terraform

# Une seule image est maintenue : NixOS + Kubernetes + GPU AMD
IMAGE   = nixos-k8s-gpu-amd
RESULT  = result-k8s-gpu-amd
KUBECFG = ./output/kubeconfig
KUBECTL = kubectl --kubeconfig $(KUBECFG) --insecure-skip-tls-verify --request-timeout=4s

# ============================================================
##@ Build & upload
# ============================================================

$(EXPORT_DIR):
	mkdir -p $(EXPORT_DIR)

build-k8s-gpu-amd: $(EXPORT_DIR) ## Construire l'image NixOS + Kubernetes + GPU AMD
	nix build ./nix#$(IMAGE) --out-link $(RESULT)
	cp -f $$(find -L $(RESULT) -name "*.qcow2" | head -1) $(EXPORT_DIR)/$(IMAGE).qcow2

upload-k8s-gpu-amd: build-k8s-gpu-amd ## Build + envoi du qcow2 — PROXMOX_SSH=<user>@<machine>
	@echo ">>> Upload vers $(PROXMOX_SSH):$(PROXMOX_IMAGE_DIR)/$(IMAGE).qcow2"
	scp -i $(SSH_KEY) $(EXPORT_DIR)/$(IMAGE).qcow2 $(PROXMOX_SSH):$(PROXMOX_IMAGE_DIR)/$(IMAGE).qcow2

# ============================================================
##@ Déploiement Kubernetes (terraform/)
# ============================================================
# Tout vit désormais dans un seul root module : terraform/
#   modules/master     → VM kubeadm + kubeconfig dans terraform/output/
#   modules/deployment → charges k8s (traefik, llm-stack, perso, ...)
#
# L'apply se fait en DEUX passes : le provider kubernetes lit
# ./output/kubeconfig au démarrage de terraform, donc le cluster doit
# exister avant que le module deployment puisse être planifié.
#
# Usage :
#   make deploy                          # passe 1 + passe 2
#   make deploy GPU=false                # sans passthrough GPU
#   make deploy CLOUDFLARE_TOKEN=xxx
#   make deploy-cluster                  # passe 1 seule (VM + kubeconfig)
#   make deploy-list                     # lister les modules déployables
#   make deploy-module MODULE=llm_stack  # (re)déployer un seul module
#   make deploy-destroy                  # détruire le cluster

CLOUDFLARE_TOKEN ?=
GPU              ?=
MODULE           ?=

TF_VARS = \
	$(if $(CLOUDFLARE_TOKEN),-var="cloudflare_tunnel_token=$(CLOUDFLARE_TOKEN)",) \
	$(if $(GPU),-var="enable_gpu_passthrough=$(GPU)",)

# Passe 1 : provision de la VM master, attente cloud-init, récupération
# du kubeconfig et attente que l'API k8s réponde.
TF_PASS1_TARGETS = \
	-target=module.master \
	-target=null_resource.ssh_known_hosts_master \
	-target=null_resource.wait_cloud_init \
	-target=null_resource.fetch_kubeconfig \
	-target=null_resource.wait_kubernetes_ready

deploy-init: ## terraform init dans terraform/
	cd $(TF_DIR) && terraform init

deploy-plan: ## Plan complet sans appliquer
	cd $(TF_DIR) && terraform plan $(TF_VARS)

deploy-cluster: deploy-init ## Passe 1 seule : VM master + kubeconfig + API k8s prête
	cd $(TF_DIR) && terraform apply -auto-approve $(TF_PASS1_TARGETS) $(TF_VARS)

deploy: deploy-cluster ## Déploiement complet : passe 1 puis passe 2 (charges k8s)
	cd $(TF_DIR) && terraform apply -auto-approve $(TF_VARS)

deploy-list: ## Lister les modules deployment disponibles et ceux dans le state
	@$(MAKE) --no-print-directory -C $(TF_DIR) list-mod

deploy-module: ## (Re)déployer un seul module — MODULE=llm_stack
ifndef MODULE
	$(error MODULE est requis. Usage: make deploy-module MODULE=llm_stack)
endif
	cd $(TF_DIR) && terraform apply -target=module.deployment.module.$(MODULE) $(TF_VARS)

deploy-module-destroy: ## Détruire un seul module — MODULE=llm_stack
ifndef MODULE
	$(error MODULE est requis. Usage: make deploy-module-destroy MODULE=llm_stack)
endif
	cd $(TF_DIR) && terraform destroy -target=module.deployment.module.$(MODULE) $(TF_VARS)

deploy-destroy: ## Détruire le cluster (retire deployment du state puis détruit master)
	cd $(TF_DIR) && terraform state rm module.deployment || true
	cd $(TF_DIR) && terraform destroy -auto-approve -target=module.master $(TF_VARS)

# ============================================================
##@ Diagnostic & maintenance
# ============================================================
# status : lecture seule — image locale, state Terraform, santé du cluster.
# N'échoue jamais, même sans build / sans state / cluster éteint.

status: ## Où on en est : image, state Terraform, cluster
	@echo ""
	@echo "═══ Image ═══════════════════════════════════════════"
	@if [ -f $(EXPORT_DIR)/$(IMAGE).qcow2 ]; then \
		ls -lh --time-style=+"%Y-%m-%d %H:%M" $(EXPORT_DIR)/$(IMAGE).qcow2 \
			| awk '{printf "  qcow2        %s   (%s %s)\n", $$5, $$6, $$7}'; \
	else \
		echo "  qcow2        absent — make build-k8s-gpu-amd"; \
	fi
	@if [ -L $(RESULT) ]; then \
		echo "  nix build    $$(readlink $(RESULT))"; \
	else \
		echo "  nix build    aucun $(RESULT)"; \
	fi
	@echo ""
	@echo "═══ Terraform ($(TF_DIR)) ═══════════════════════════"
	@if [ -d $(TF_DIR)/.terraform ]; then \
		echo "  init         ok"; \
	else \
		echo "  init         manquant — make deploy-init"; \
	fi
	@if [ -s $(TF_DIR)/terraform.tfstate ]; then \
		cd $(TF_DIR) && \
		echo "  master       $$(terraform output -raw master_vm_name 2>/dev/null || echo '?')" \
		     "(id $$(terraform output -raw master_vm_id 2>/dev/null || echo '?'))" \
		     "— $$(terraform output -raw master_vm_ip 2>/dev/null \
		           || sed -n 's/^vm_ip *= *"\(.*\)"/\1/p' terraform.tfvars)" && \
		echo "  ressources   $$(terraform state list 2>/dev/null | wc -l)" && \
		echo "  modules      $$(terraform state list 2>/dev/null \
			| sed -n 's/^module\.deployment\.module\.\([^.]*\).*/\1/p' \
			| sort -u | tr '\n' ' ')"; \
	else \
		echo "  state        vide — rien de déployé"; \
	fi
	@echo ""
	@echo "═══ Cluster ═════════════════════════════════════════"
	@if [ ! -f $(TF_DIR)/$(KUBECFG) ]; then \
		echo "  kubeconfig   absent — make deploy-cluster"; \
	else \
		cd $(TF_DIR) && \
		api=$$(grep -m1 'server:' $(KUBECFG) | awk '{print $$2}'); \
		if timeout 6 $(KUBECTL) get nodes >/dev/null 2>&1; then \
			echo "  api          $$api  joignable"; \
			$(KUBECTL) get nodes --no-headers 2>/dev/null \
				| awk '{printf "  node         %-22s %-12s %s\n", $$1, $$2, $$5}'; \
			$(KUBECTL) get pods -A --no-headers 2>/dev/null \
				| awk '$$4=="Running"||$$4=="Completed"{ok++} {n++} \
				       END{printf "  pods         %d/%d ok\n", ok, n}'; \
			$(KUBECTL) get pods -A --no-headers 2>/dev/null \
				| awk '$$4!="Running"&&$$4!="Completed"{printf "  ! pod        %s/%s  %s\n", $$1, $$2, $$4}'; \
			$(KUBECTL) get svc -A --no-headers 2>/dev/null \
				| awk '$$3=="LoadBalancer"{printf "  lb           %-22s %s\n", $$1"/"$$2, $$5}'; \
		else \
			echo "  api          $$api  INJOIGNABLE (VM éteinte ? réseau ?)"; \
		fi; \
	fi
	@echo ""

# ============================================================
# Préparer le template : nettoyer l'état cloud-init
# ============================================================
# Usage : make prepare-template TEMPLATE_IP=192.168.99.X
#
# Étapes :
#   1. Crée /var/lib/cloud/clean-on-shutdown sur la VM template
#   2. Arrête proprement la VM
#   → cloud-init-clean.service s'exécute au shutdown et efface le cache
#   → Le prochain déploiement depuis ce template verra new=True

prepare-template: ## Nettoyer cloud-init avant snapshot template — TEMPLATE_IP=<ip>
ifndef TEMPLATE_IP
	$(error TEMPLATE_IP est requis. Usage: make prepare-template TEMPLATE_IP=<ip>)
endif
	@echo ">>> Marquage de la VM $(TEMPLATE_IP) pour nettoyage cloud-init..."
	ssh -i $(SSH_KEY) $(TEMPLATE_USER)@$(TEMPLATE_IP) \
		"sudo touch /var/lib/cloud/clean-on-shutdown"
	@echo ">>> Arrêt de la VM (cloud-init-clean va s'exécuter)..."
	ssh -i $(SSH_KEY) $(TEMPLATE_USER)@$(TEMPLATE_IP) \
		"sudo systemctl poweroff" || true
	@echo ">>> VM arrêtée. Elle est prête à être convertie en template Proxmox."

# ============================================================

# L'aide se génère depuis le Makefile lui-même : chaque cible documentée porte
# un commentaire "## description" sur sa ligne, chaque section un "##@ Titre",
# chaque variable une ligne "#> NOM  description". Rien à maintenir en double.

help: ## Afficher cette aide
	@printf "\nUsage: make <cible> [VAR=valeur]\n"
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@ / { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*## / { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }' \
		$(MAKEFILE_LIST)
	@printf "\n\033[1mVariables\033[0m\n"
	@awk '/^#> / { name = $$2; $$1 = ""; $$2 = ""; sub(/^ +/, ""); \
		printf "  \033[36m%-18s\033[0m %s\n", name, $$0 }' $(MAKEFILE_LIST)
	@printf "\nExemples:\n"
	@printf "  make status\n"
	@printf "  make upload-k8s-gpu-amd PROXMOX_SSH=nico@192.168.1.50\n"
	@printf "  make deploy GPU=false\n"
	@printf "  make deploy-module MODULE=llm_stack\n"
	@printf "  make prepare-template TEMPLATE_IP=192.168.99.10\n\n"
