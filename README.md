# nixos-base-image

> [!WARNING]
> **Projet arrêté — dépôt non maintenu.**
>
> Le développement s'arrête ici et aucune évolution supplémentaire n'est prévue. Le
> dépôt reste volontairement en ligne comme une relique technique et un retour
> d'expérience. Ce n'est ni une solution clé en main, ni une configuration dont le
> fonctionnement est garanti sur un autre matériel.

Repo personnel : construction d'une image NixOS pour Proxmox, et déploiement d'un
cluster Kubernetes mono-nœud dessus avec ses charges applicatives.

## Pourquoi le projet s'arrête

L'expérience n'est pas un échec complet : l'image a été construite, le cluster kubeadm
a démarré et le GPU AMD avec ROCm a bien été utilisé depuis Kubernetes sur le matériel
d'origine. La limite persistante se trouve dans le cycle de vie du passthrough PCIe
AMD, plus précisément dans la réinitialisation de la carte entre deux utilisations.

Après un reset raté, le GPU peut rester bloqué et figer OVMF avant même que NixOS ne
démarre. La VM n'a alors ni réseau ni agent QEMU, Terraform finit par expirer en
attendant SSH et un redémarrage de l'hôte Proxmox est généralement nécessaire. Les
options `gpu_rombar = false` et `make deploy GPU=false` permettent de contourner ou de
diagnostiquer le problème, mais ne le résolvent pas durablement. Les détails sont dans
[docs/gpu-amd.md](docs/gpu-amd.md#le-reset-bug).

Les derniers changements ont surtout retiré les restes des architectures précédentes
— script VLAN inutilisé, commande de jonction et port hérités des anciens workers —
sans pouvoir rendre le passthrough AMD suffisamment fiable pour poursuivre ce projet.

## Pourquoi conserver ce dépôt

Ce dépôt restera en ligne comme une relique technique. Il peut encore servir de point
de départ à celles et ceux qui veulent expérimenter un GPU AMD avec ROCm dans
Kubernetes sur NixOS, derrière Proxmox. Il documente autant ce qui a fonctionné que
les contournements et les limites rencontrées ; il ne constitue pas une solution prête
à déployer ni une promesse de compatibilité avec un autre GPU ou une autre plateforme.

Il contient notamment des exemples pour :

- produire une image NixOS `qcow2` destinée à Proxmox ;
- adapter kubeadm aux particularités de NixOS ;
- automatiser en deux passes le cluster et ses charges avec Terraform ;
- exposer un GPU AMD, `/dev/kfd` et `/dev/dri` à des pods utilisant ROCm ;
- comprendre les essais, les contournements et les impasses de cette combinaison.

Tout passe par le `Makefile` :

```bash
make            # liste des cibles et variables
make status     # état local de la dernière version du projet
```

## Ce que ça fait

Une image NixOS `qcow2` est construite par un flake, envoyée sur Proxmox et convertie
en template. Terraform clone ce template, et un cloud-init transforme la VM en nœud
kubeadm complet (containerd, kubelet, Calico). Terraform récupère ensuite le
kubeconfig et déploie les charges : MetalLB, Traefik, un tunnel Cloudflare, et les
stacks applicatives.

Le cluster est **mono-nœud** — le control-plane fait aussi tourner les charges.

## Arborescence

```
nixos-base-image/
├── nix/                    Image NixOS (flake → qcow2)
│   ├── flake.nix           Point d'entrée
│   ├── configuration.nix   Base commune
│   ├── k8s.nix             Surcouche Kubernetes
│   ├── gpu-amd.nix         Surcouche GPU AMD / ROCm
│   ├── hardware-image.nix  Filesystems + bootloader
│   └── machine.nix         Placeholder, écrasé au déploiement
├── terraform/              Root module unique
│   ├── main.tf             Orchestration + jonction entre les deux modules
│   ├── modules/master/     La VM Proxmox et son cloud-init
│   └── modules/deployment/ Les charges k8s (7 sous-modules)
├── docs/                   Documentation détaillée
└── Makefile                Build, upload, déploiement, status
```

## Reprendre ou expérimenter

Les commandes ci-dessous décrivent la dernière version connue du workflow. Elles sont
une base à adapter et à valider sur son propre matériel, pas une procédure maintenue.

Prérequis : Nix avec les flakes, Terraform, kubectl, un accès SSH au nœud Proxmox, et
un `terraform/terraform.tfvars` renseigné (voir plus bas).

```bash
make build-k8s-gpu-amd                             # construire l'image (~5,4 Go)
make upload-k8s-gpu-amd PROXMOX_SSH=root@pve       # l'envoyer sur Proxmox
make prepare-template TEMPLATE_IP=192.168.99.x     # purger cloud-init avant snapshot
                                                    # → convertir en template (Proxmox)
make deploy                                        # déployer le cluster et les charges
```

Le déploiement se fait **en deux passes**, enchaînées automatiquement par
`make deploy`. Un `terraform apply` lancé à la main sur un cluster inexistant échoue :
les providers Kubernetes et Helm lisent le kubeconfig au démarrage du plan. Voir
[docs/architecture.md](docs/architecture.md#pourquoi-deux-passes).

## Configuration

`terraform/terraform.tfvars` porte toute la configuration : accès à l'API Proxmox,
dimensionnement de la VM, plan VLAN, et les secrets des différentes stacks.

**Ce fichier contient des secrets en clair** (token API Proxmox, token Cloudflare,
clé GPG privée Passbolt, mots de passe Postgres). Il est gitignoré, tout comme le
state Terraform et le kubeconfig récupéré. Ne pas les commiter.

Les variables et leurs valeurs par défaut sont documentées dans
[terraform/variables.tf](terraform/variables.tf).

## GPU AMD

Le passthrough PCIe est activé par défaut et repose sur un *resource mapping* Proxmox
(`Datacenter → Resource Mappings → PCI Devices`). Pour isoler un problème lié à la
carte, la VM peut être déployée sans GPU :

```bash
make deploy GPU=false
```

`gpu_rombar = false` est également la valeur par défaut. Ces deux options sont des
contournements du reset bug décrit plus haut, pas une correction de fond.

## Documentation

- [CLAUDE.md](CLAUDE.md) — carte du repo et règles, pour les agents IA
- [docs/architecture.md](docs/architecture.md) — la chaîne complète, du qcow2 au pod
- [docs/workflow.md](docs/workflow.md) — builder, uploader, déployer, cibler, détruire
- [docs/reseau.md](docs/reseau.md) — interfaces, VLANs, exposition des services, IPs
- [docs/nixos-image.md](docs/nixos-image.md) — le flake et les contraintes NixOS
- [docs/gpu-amd.md](docs/gpu-amd.md) — passthrough AMD, reset bug, ROCm
- [docs/secrets.md](docs/secrets.md) — ce qui est sensible et comment le traiter
