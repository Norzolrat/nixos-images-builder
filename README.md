# nixos-base-image

Ce dépôt personnel a servi à construire et déployer des images NixOS sur Proxmox comme base d'une infrastructure expérimentale.

> [!WARNING]
> **Projet arrêté — dépôt non maintenu.**
>
> Le développement s'arrête ici et aucune évolution supplémentaire n'est prévue. Le dépôt reste volontairement en ligne comme une relique technique et un retour d'expérience. Ce n'est ni une solution clé en main, ni une configuration dont le fonctionnement est garanti sur un autre matériel.

## Pourquoi le projet s'arrête

L'expérience n'est pas un échec complet : les images NixOS ont été construites, le cluster kubeadm a démarré et le GPU AMD avec ROCm a réellement été utilisé depuis Kubernetes sur le matériel d'origine. La limite durable se trouve dans la fiabilité du cycle de vie du passthrough PCIe AMD, en particulier dans la réinitialisation de la carte entre deux utilisations.

Après un reset raté, le GPU peut rester bloqué et figer OVMF avant même le démarrage de NixOS. La VM n'a alors ni réseau ni agent QEMU, et les automatisations finissent par expirer en attendant une machine qui ne démarrera pas. Un redémarrage de l'hôte Proxmox est généralement nécessaire pour récupérer la carte. Les derniers changements ont amélioré plusieurs aspects du provisionnement NixOS, du réseau et du déploiement, mais n'ont pas rendu ce passthrough suffisamment reproductible pour poursuivre vers une infrastructure stable.

Le projet s'arrête donc sur un prototype qui a fonctionné, mais dont la dépendance au comportement matériel et firmware du GPU empêche de promettre un usage fiable ou maintenable.

## Pourquoi conserver ce dépôt

Ce dépôt restera en ligne comme une relique technique. Il peut encore servir de point de départ à celles et ceux qui veulent expérimenter un GPU AMD avec ROCm dans Kubernetes sur NixOS, derrière Proxmox. Il documente autant ce qui a fonctionné que les essais et les limites rencontrées ; il ne constitue pas une recette universelle ni une promesse de compatibilité avec un autre GPU ou une autre plateforme.

Il contient notamment des exemples pour :

- produire plusieurs variantes d'images NixOS `qcow2` destinées à Proxmox ;
- déployer avec Terraform un cluster kubeadm composé d'un master et de workers, ou une variante mono-nœud ;
- attacher un GPU AMD à une VM dédiée ou à un worker Kubernetes ;
- déployer le device plugin AMD et exposer `/dev/kfd` et `/dev/dri` à des pods ;
- tester ROCm avec PyTorch et expérimenter des charges comme Ollama ou ComfyUI.

Les sections suivantes décrivent le dernier état historique de la branche. Les commandes et configurations sont conservées comme matériau d'expérimentation : elles doivent être relues, adaptées et validées sur son propre environnement.

## Vue d'ensemble

```
nixos-base-image/
├── nix/                  # Définitions des images NixOS (flake)
│   ├── flake.nix         # Point d'entrée — quatre packages qcow2
│   ├── configuration.nix # Image de base commune
│   ├── k8s.nix           # Surcouche Kubernetes
│   └── gpu-amd.nix       # Surcouche AMD ROCm
├── tf-base/              # Terraform — VM NixOS générique
├── tf-amd_card/          # Terraform — VM dédiée avec passthrough AMD
├── tf-kube/              # Terraform — cluster kubeadm master + workers
│   └── modules/
│       ├── master/       # Nœud control-plane (kubeadm init + Calico)
│       ├── worker/       # Workers CPU (kubeadm join)
│       └── worker-gpu-amd/ # Workers avec passthrough AMD
├── tf-mono/              # Terraform — variante kubeadm mono-nœud et ses charges
├── tf-deploy/            # Terraform — charges Kubernetes historiques
└── Makefile              # Commandes build / upload / préparation template
```

## Images NixOS

### nixos-base

Image minimaliste à usage générique. Elle inclut :

- Cloud-init (réseau + hostname gérés automatiquement)
- QEMU guest agent
- SSH sans authentification par mot de passe pour root
- Fish comme shell par défaut avec un prompt et des aliases prêts à l'emploi
- Packages de base : `vim`, `git`, `curl`, `wget`, `htop`, `busybox`
- Nix flakes activé

### nixos-k8s

Étend `nixos-base` avec tout ce qu'il faut pour faire tourner un nœud Kubernetes :

- Modules kernel : `br_netfilter`, `overlay`, `ip_vs`, `wireguard`
- Paramètres sysctl pour le networking K8s
- `containerd` comme container runtime (CRI configuré, cgroups systemd)
- CNI plugins dans `/opt/cni/bin` (répertoire inscriptible pour Cilium/Calico)
- Packages : `kubectl`, `kubernetes`, `helm`, `cri-tools`, `conntrack-tools`, etc.
- `kubelet` en unité systemd compatible kubeadm (NixOS read-only oblige)
- Ports firewall ouverts pour le control-plane, kubelet, BGP et VXLAN

### Variantes GPU AMD

Le flake expose également `nixos-gpu-amd` et `nixos-k8s-gpu-amd`. Elles ajoutent la configuration `amdgpu`, les outils ROCm et les permissions nécessaires à `/dev/kfd` et aux périphériques de rendu. La seconde combine cette surcouche avec Kubernetes.

## Workflow historique — construire et uploader une image

### 1. Builder

```bash
make build-base           # → export/nixos-base.qcow2
make build-kube           # → export/nixos-k8s.qcow2
make build-gpu-amd        # → export/nixos-gpu-amd.qcow2
make build-k8s-gpu-amd    # → export/nixos-k8s-gpu-amd.qcow2
```

### 2. Uploader vers Proxmox

```bash
make upload-base          # build + scp vers le nœud Proxmox
make upload-kube
make upload-gpu-amd
make upload-k8s-gpu-amd
```

Variables disponibles :

| Variable | Défaut | Description |
|---|---|---|
| `PROXMOX_HOST` | `pve` | Hostname du nœud Proxmox |
| `PROXMOX_USER` | `root@pam` | Utilisateur SSH |
| `PROXMOX_STORE` | `local` | Datastore Proxmox |

### 3. Créer un template Proxmox

Avant de convertir une VM en template, cloud-init doit être nettoyé pour que chaque clone repart d'un état vierge.

```bash
make prepare-template TEMPLATE_IP=192.168.99.x
```

Ce que ça fait :
1. Crée `/var/lib/cloud/clean-on-shutdown` sur la VM
2. Éteint la VM proprement
3. Le service `cloud-init-clean` s'exécute au shutdown : efface le cache cloud-init, le hostname persisté et vide `/etc/machine-id` (chaque clone en génèrera un unique au boot)

La VM peut ensuite être convertie en template via l'interface Proxmox.

## Déploiement Kubernetes — tf-kube

Terraform déploie un cluster kubeadm complet (1 master + N workers CPU ou GPU AMD) sur Proxmox à partir d'une image Kubernetes adaptée.

**Prérequis :** l'image `nixos-k8s.qcow2`, et `nixos-k8s-gpu-amd.qcow2` si des workers GPU sont demandés, doivent être uploadées sur Proxmox au préalable.

### Configuration

Copier et adapter `terraform.tfvars` :

```hcl
proxmox_api_url    = "https://<proxmox>:8006/api2/json"
proxmox_user       = "terraform@pve"
proxmox_token_name = "terraform"
proxmox_token      = "<token>"

nixos_image_file_id = "local:iso/nixos-k8s.qcow2"

vm_ip          = "192.168.99.186/24"  # master — workers = IP+1, IP+2, ...
vm_gateway     = "192.168.99.254"
worker_count   = 2

manager_user           = "user"
manager_ssh_public_key = "<clé publique SSH>"
ssh_private_key_path   = "~/.ssh/id_rsa"
```

### Déployer

```bash
cd tf-kube
terraform init
terraform apply
```

### Ce que Terraform fait

1. Crée la VM master, lui injecte un cloud-init qui :
   - Lance `kubeadm init` avec le CIDR configuré
   - Installe Calico comme CNI
   - Copie le kubeconfig dans `~/kubeconfig`
2. Récupère ce kubeconfig et génère par SSH un script `kubeadm join` temporaire.
3. Crée les VMs workers CPU et, si demandé, les workers GPU AMD avec leur resource mapping PCI.
4. Copie et exécute le script de jonction sur chaque worker, puis applique le label `gpu=amd` aux nœuds GPU prêts.

### Récupérer le kubeconfig

```bash
cp ../export/kubeconfig ~/.kube/config
```

## Détails techniques

### Hostname sous NixOS + cloud-init

NixOS réapplique `networking.hostName` à chaque boot, écrasant ce que cloud-init a défini. Le service `cloud-hostname-restore` contourne ce problème en lisant le hostname écrit par cloud-init dans `/var/lib/cloud-hostname` et en le réappliquant après l'activation NixOS.

### kubelet et NixOS read-only

kubeadm s'attend à pouvoir écrire un drop-in dans `/etc/systemd/system/`. Ce répertoire est en lecture seule sur NixOS. L'unité kubelet définie dans `k8s.nix` hard-code les flags que kubeadm y mettrait normalement, et lit `kubeadm-flags.env` via `EnvironmentFile`. kubelet crashe en boucle jusqu'à ce que kubeadm ait écrit `/var/lib/kubelet/config.yaml` — c'est le comportement attendu, `Restart=always` gère ça.
