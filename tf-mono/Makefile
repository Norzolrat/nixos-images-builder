.PHONY: apply destroy init kube kube-del

# Deux passes obligatoires :
# 1) provision du cluster + récupération du kubeconfig frais + join command
# 2) worker GPU (si activé) + déploiements K8s
#    (le provider kubernetes lit le kubeconfig au démarrage de terraform)
apply:
	terraform apply -target=module.master \
	                -target=null_resource.ssh_known_hosts_master \
	                -target=null_resource.wait_cloud_init \
	                -target=null_resource.fetch_kubeconfig \
	                -target=null_resource.wait_kubernetes_ready

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
	terraform destroy

init:
	terraform init
