# nixos-base-image

Repo personnel : construction d'une image NixOS pour Proxmox, et déploiement d'un
cluster Kubernetes mono-nœud dessus avec ses charges applicatives.

Tout passe par le `Makefile` :

```bash
make            # liste des cibles et variables
make status     # où en est le projet : image, state Terraform, cluster
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

## Démarrage

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
(`Datacenter → Resource Mappings → PCI Devices`). Une carte AMD peut rester bloquée
après un reset raté et figer OVMF avant même le boot — la VM n'a alors ni réseau ni
agent. Deux échappatoires :

```bash
make deploy GPU=false     # déployer sans la carte
```

et `gpu_rombar = false` (le défaut), qui évite que le firmware exécute la vBIOS au
démarrage.

## Documentation

- [CLAUDE.md](CLAUDE.md) — carte du repo et règles, pour les agents IA
- [docs/architecture.md](docs/architecture.md) — la chaîne complète, du qcow2 au pod
- [docs/workflow.md](docs/workflow.md) — builder, uploader, déployer, cibler, détruire
- [docs/reseau.md](docs/reseau.md) — interfaces, VLANs, exposition des services, IPs
- [docs/nixos-image.md](docs/nixos-image.md) — le flake et les contraintes NixOS
- [docs/gpu-amd.md](docs/gpu-amd.md) — passthrough AMD, reset bug, ROCm
- [docs/secrets.md](docs/secrets.md) — ce qui est sensible et comment le traiter
