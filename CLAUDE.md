# nixos-base-image — guide pour agents

Construction d'une image NixOS (qcow2) pour Proxmox, et déploiement d'un cluster
kubeadm **mono-nœud** dessus via Terraform, avec les charges applicatives.

## Carte du repo

| Chemin | Rôle |
|---|---|
| [nix/](nix/) | Définition de l'image NixOS (flake → qcow2). Une seule image maintenue : `nixos-k8s-gpu-amd`. |
| [terraform/](terraform/) | Root module unique. `modules/master` = la VM, `modules/deployment` = les charges k8s. |
| [Makefile](Makefile) | Toutes les commandes. `make help` est auto-généré, il fait foi. |
| [docs/](docs/) | Documentation détaillée (voir index plus bas). |
| `export/`, `result-*` | Artefacts de build, gitignorés. |

## Règles dures

1. **`terraform/terraform.tfvars` contient des secrets en clair** (token API Proxmox,
   token Cloudflare, clé GPG privée Passbolt, mots de passe Postgres). Il est
   gitignoré. Ne jamais l'afficher, le copier dans un message, ni le commiter.
   Même chose pour `terraform/terraform.tfstate` et `terraform/output/kubeconfig`.

2. **L'apply Terraform se fait en deux passes.** Un `terraform apply` global à froid
   échoue : les providers `kubernetes` et `helm` lisent `./output/kubeconfig` au
   démarrage de Terraform, avant que le cluster existe. Toujours passer par
   `make deploy` (qui enchaîne les deux passes) ou `make deploy-cluster` puis
   `make deploy`. Détail : [docs/architecture.md](docs/architecture.md).

3. **Ne pas éditer [nix/machine.nix](nix/machine.nix)** : c'est un placeholder,
   écrasé au premier boot par le fichier généré depuis
   `terraform/modules/master/templates/machine.nix.tpl`. Pour changer l'IP ou les
   VLANs, c'est le template qu'il faut modifier.

4. **Une seule image existe** (`nixos-k8s-gpu-amd` = base + k8s + GPU AMD). Le flake
   expose encore `nixos-base`, `nixos-k8s` et `nixos-gpu-amd`, mais aucune cible make
   ne les construit et elles ne sont plus déployées.

5. **Vérifier avant d'affirmer.** Ce repo a déjà eu une doc qui décrivait une
   arborescence disparue (`tf-kube/`, un module `worker/`), ce qui a produit des bugs.
   Si un fait de cette doc est contredit par le code, c'est le code qui gagne — et il
   faut corriger la doc dans la foulée.

## Commandes

`make help` liste toutes les cibles et variables — il se génère depuis le Makefile,
il ne peut pas être périmé. Ne pas dupliquer cette liste ailleurs.

`make status` donne l'état réel : image buildée ou non, contenu du state Terraform,
cluster joignable ou non. À lancer avant de diagnostiquer quoi que ce soit.

## Index de la doc

- [docs/architecture.md](docs/architecture.md) — la chaîne complète, du qcow2 au pod.
  Ce qui se passe pendant un déploiement, dans l'ordre, et pourquoi deux passes.
- [docs/workflow.md](docs/workflow.md) — cycle de vie : builder, uploader, créer le
  template, déployer, cibler une seule stack, détruire.
- [docs/reseau.md](docs/reseau.md) — interfaces, plan VLAN, exposition des services,
  MetalLB, plages d'IP, pare-feu.
- [docs/nixos-image.md](docs/nixos-image.md) — le flake, le double usage des `.nix`,
  et ce que NixOS impose à kubeadm.
- [docs/gpu-amd.md](docs/gpu-amd.md) — passthrough, reset bug, ROCm, diagnostic.
- [docs/secrets.md](docs/secrets.md) — inventaire et règles de manipulation.

Trois `CLAUDE.md` locaux complètent celui-ci, chargés quand on travaille dans leur
répertoire : [nix/](nix/CLAUDE.md), [terraform/](terraform/CLAUDE.md) et
[terraform/modules/deployment/](terraform/modules/deployment/CLAUDE.md).

## Conventions

- Le projet est commenté et documenté **en français**.
- Les commentaires du code expliquent *pourquoi*, pas *quoi* — garder ce style.
- Un fait ne vit qu'à un seul endroit. Plutôt qu'une redite, mettre un lien.
