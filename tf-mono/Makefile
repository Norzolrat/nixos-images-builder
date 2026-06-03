.PHONY: apply destroy init

# Deux passes obligatoires :
# 1) provision du cluster + récupération du kubeconfig frais + join command
# 2) worker GPU (si activé) + déploiements K8s
#    (le provider kubernetes lit le kubeconfig au démarrage de terraform)
apply:
	terraform apply -target=module.master \
	                -target=null_resource.ssh_known_hosts_master \
	                -target=null_resource.wait_cloud_init \
	                -target=null_resource.fetch_kubeconfig
	terraform apply

destroy:
	terraform state rm module.deployment || true
	terraform destroy

init:
	terraform init
