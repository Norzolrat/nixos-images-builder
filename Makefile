.PHONY: build-base build-k8s build-gpu-amd upload-base upload-k8s upload-gpu-amd prepare-template help

PROXMOX_HOST  ?= pve
PROXMOX_USER  ?= root@pam
PROXMOX_STORE ?= local
TEMPLATE_IP   ?=
TEMPLATE_USER ?= user
SSH_KEY       ?= ~/.ssh/id_ed25519_terraform

EXPORT_DIR = ./export

# ============================================================
# Build
# ============================================================

$(EXPORT_DIR):
	mkdir -p $(EXPORT_DIR)

build-base: $(EXPORT_DIR)
	nix build ./nix#nixos-base --out-link result-base
	cp -f $$(find -L result-base -name "*.qcow2" | head -1) $(EXPORT_DIR)/nixos-base.qcow2

build-kube: $(EXPORT_DIR)
	nix build ./nix#nixos-k8s --out-link result-k8s
	cp -f $$(find -L result-k8s -name "*.qcow2" | head -1) $(EXPORT_DIR)/nixos-k8s.qcow2

build-gpu-amd: $(EXPORT_DIR)
	nix build ./nix#nixos-gpu-amd --out-link result-gpu-amd
	cp -f $$(find -L result-gpu-amd -name "*.qcow2" | head -1) $(EXPORT_DIR)/nixos-gpu-amd.qcow2

# ============================================================
# Upload vers Proxmox
# ============================================================

upload-base: build-base
	scp -i $(SSH_KEY) $(EXPORT_DIR)/nixos-base.qcow2 $(PROXMOX_USER)@$(PROXMOX_HOST):/var/lib/vz/import/images/0/nixos-base.qcow2

upload-kube: build-kube
	scp -i $(SSH_KEY) $(EXPORT_DIR)/nixos-k8s.qcow2 $(PROXMOX_USER)@$(PROXMOX_HOST):/var/lib/vz/import/images/0/nixos-k8s.qcow2

upload-gpu-amd: build-gpu-amd
	scp -i $(SSH_KEY) $(EXPORT_DIR)/nixos-gpu-amd.qcow2 $(PROXMOX_USER)@$(PROXMOX_HOST):/var/lib/vz/import/images/0/nixos-gpu-amd.qcow2

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

prepare-template:
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

help:
	@echo "Targets disponibles:"
	@echo "  build-base            Construire l'image NixOS de base"
	@echo "  build-k8s             Construire l'image NixOS + Kubernetes"
	@echo "  build-gpu-amd         Construire l'image NixOS + AMD GPU (ROCm / Docker)"
	@echo "  upload-base           Build + upload vers Proxmox"
	@echo "  upload-k8s            Build + upload vers Proxmox (k8s)"
	@echo "  upload-gpu-amd        Build + upload vers Proxmox (AMD GPU)"
	@echo "  prepare-template      Nettoyer cloud-init avant création du template"
	@echo "                        Requiert: TEMPLATE_IP=<ip>"
	@echo ""
	@echo "Variables:"
	@echo "  PROXMOX_HOST   Hôte Proxmox        (défaut: pve)"
	@echo "  PROXMOX_USER   User SSH Proxmox     (défaut: root@pam)"
	@echo "  TEMPLATE_IP    IP de la VM template  (requis pour prepare-template)"
	@echo "  TEMPLATE_USER  User SSH template     (défaut: user)"
	@echo "  EXPORT_DIR     Répertoire de sortie  (défaut: ./export)"
