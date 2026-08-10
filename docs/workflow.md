# Workflow

Cycle de vie complet. Les cibles et variables exactes sont dans `make help` — ce
document explique l'ordre et les moments où il faut faire attention.

## Vue rapide

```
make build-k8s-gpu-amd     →  export/nixos-k8s-gpu-amd.qcow2
make upload-k8s-gpu-amd    →  dépôt sur Proxmox        (PROXMOX_SSH=user@machine)
   (création du template Proxmox, à la main)
make deploy                →  VM + cluster + charges k8s
make status                →  où on en est
```

## 1. Builder l'image

```bash
make build-k8s-gpu-amd
```

Lance `nix build ./nix#nixos-k8s-gpu-amd`, puis copie le qcow2 hors du store vers
`export/`. Compter ~5,4 Go et un temps de build conséquent au premier coup.

Toute modification de [nix/configuration.nix](../nix/configuration.nix),
[nix/k8s.nix](../nix/k8s.nix) ou [nix/gpu-amd.nix](../nix/gpu-amd.nix) impose de
rebuilder **et** de recréer le template Proxmox : les VMs existantes ne sont pas
mises à jour rétroactivement.

À noter : ces trois fichiers sont aussi injectés dans la VM au déploiement (voir
[architecture.md](architecture.md)). Une modif prise en compte par Terraform sans
rebuild de l'image reste donc possible — c'est `nixos-rebuild switch` dans la VM qui
l'appliquera au premier boot, au prix d'un boot plus long.

## 2. Uploader vers Proxmox

```bash
make upload-k8s-gpu-amd PROXMOX_SSH=user@machine
```

La cible rebuild d'abord si nécessaire, puis `scp` vers `PROXMOX_IMAGE_DIR`
(`/var/lib/vz/import/images/0` par défaut). La destination est affichée avant
l'envoi — une bonne raison de la lire avant de pousser plusieurs gigaoctets.

`PROXMOX_SSH` attend un **utilisateur SSH**, pas l'utilisateur API Proxmox : `root@pve`,
jamais `root@pam@pve`. Le realm `@pam` ne concerne que l'API, utilisée par Terraform
via `proxmox_user` dans `terraform.tfvars`.

## 3. Créer le template Proxmox

Étape manuelle, à faire une fois par nouvelle image. Avant de convertir la VM en
template, l'état cloud-init doit être purgé, sinon chaque clone héritera du cache de
la VM d'origine et ne se reconfigurera pas.

```bash
make prepare-template TEMPLATE_IP=192.168.99.x
```

La cible pose `/var/lib/cloud/clean-on-shutdown` sur la VM puis l'éteint proprement.
Le service `cloud-init-clean` s'exécute au shutdown : il efface le cache cloud-init,
le hostname persisté, et vide `/etc/machine-id`. La VM peut ensuite être convertie en
template depuis l'interface Proxmox.

## 4. Déployer

```bash
make deploy                       # les deux passes
make deploy GPU=false             # sans passthrough GPU
make deploy CLOUDFLARE_TOKEN=xxx
```

`make deploy` enchaîne la passe 1 (VM, cloud-init, kubeconfig, attente de l'API) puis
la passe 2 (charges k8s). Voir [architecture.md](architecture.md#pourquoi-deux-passes)
pour la raison de ce découpage — ce n'est pas contournable.

`make deploy-cluster` s'arrête après la passe 1, utile pour inspecter le cluster avant
d'y poser quoi que ce soit.

`make deploy-plan` planifie sans appliquer, mais **ne fonctionne que si le cluster
existe déjà** : sur un cluster absent, le plan échoue à l'initialisation des providers.

Prérequis pour toute cette étape : `terraform/terraform.tfvars` renseigné (jamais
commité), le template Proxmox créé, et `nixos_image_file_id` qui pointe dessus.

## 5. Travailler sur une seule stack

Redéployer tout pour changer Traefik est inutilement long :

```bash
make deploy-list                        # ce qui existe, et ce qui est dans le state
make deploy-module MODULE=llm_stack     # (re)déployer une stack
make deploy-module-destroy MODULE=llm_stack
```

Le nom à passer est celui du bloc `module` dans
[terraform/modules/deployment/main.tf](../terraform/modules/deployment/main.tf) —
attention, c'est `llm_stack` (underscore) alors que le répertoire s'appelle
`llm-stack` (tiret).

MetalLB est une dépendance de fait de toutes les stacks qui exposent un
`LoadBalancer`. Le détruire seul laisse les autres services sans IP.

## 6. Savoir où on en est

```bash
make status
```

Lecture seule, ne déclenche aucun apply. Affiche l'image locale et sa date, l'état du
state Terraform (VM master, nombre de ressources, stacks déployées), et la santé du
cluster (nœuds, ratio de pods sains, pods en échec, services LoadBalancer et leurs
IPs). Si le cluster ne répond pas, la sonde est bornée à 6 secondes et le dit
franchement plutôt que de faire attendre.

## 7. Détruire

```bash
make deploy-destroy
```

Retire `module.deployment` du state, puis détruit `module.master`. Le retrait du state
est nécessaire : une fois la VM éteinte, un plan touchant des ressources Kubernetes ne
peut plus aboutir. Les ressources k8s disparaissent de toute façon avec la VM.

## État persistant

Le state Terraform est **local** : `terraform/terraform.tfstate`, gitignoré, sans
backend distant ni verrou. Deux conséquences : il n'existe qu'un seul exemplaire, sur
cette machine, et rien n'empêche deux applies concurrents de se marcher dessus.
Sauvegarder ce fichier avant toute manipulation risquée (`state rm`, `import`).

Les données applicatives persistent sur le nœud via des `hostPath`, aux chemins
définis par les variables `*_host_data_path` (`/opt/traefik-acme`, `/opt/teleport`,
`/opt/perso`, `/opt/llm`, ...). Elles survivent à un `deploy-module-destroy`, mais pas
à la destruction de la VM.
