.PHONY: apply destroy init kube kube-del list-mod

# Deux passes obligatoires :
# 1) provision du cluster + récupération du kubeconfig frais
# 2) déploiements K8s
#    (le provider kubernetes lit le kubeconfig au démarrage de terraform)
apply:
	terraform apply -target=module.master \
	                -target=null_resource.ssh_known_hosts_master \
	                -target=null_resource.wait_cloud_init \
	                -target=null_resource.fetch_kubeconfig \
	                -target=null_resource.wait_kubernetes_ready

list-mod:
	@echo "=== Modules disponibles (nom MODULE= à utiliser) ==="
	@grep '^module "' modules/deployment/main.tf | sed 's/module "\(.*\)" {/\1/'
	@echo ""
	@echo "=== Modules dans le state Terraform ==="
	@terraform state list 2>/dev/null | grep "^module\.deployment\.module\." | sed 's/module\.deployment\.module\.\([^.]*\).*/\1/' | sort -u

# Usage : make kube MODULE=llm_stack | traefik | cloudflare | mario | starwars | matrix
kube:
ifndef MODULE
	$(error MODULE est requis — ex: make kube MODULE=llm_stack)
endif
	terraform apply -target=module.deployment.module.$(MODULE)

# Usage : make kube-del MODULE=llm_stack | traefik | cloudflare | mario | starwars | matrix
kube-del:
ifndef MODULE
	$(error MODULE est requis — ex: make kube-del MODULE=llm_stack)
endif
	terraform destroy -target=module.deployment.module.$(MODULE)

destroy:
	terraform state rm module.deployment || true
	terraform destroy -target=module.master

init:
	terraform init
