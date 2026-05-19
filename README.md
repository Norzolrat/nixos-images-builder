# nixos-base-image

Repo personnel pour construire et déployer des images NixOS sur Proxmox. Ces images servent de base à l'infrastructure.

## Vue d'ensemble

```
nixos-base-image/
├── nix/                  # Définitions des images NixOS (flake)
│   ├── flake.nix         # Point d'entrée — deux packages qcow2
│   ├── configuration.nix # Image de base (commune aux deux)
│   └── k8s.nix           # Surcouche Kubernetes
├── tf-kube/              # Terraform — déploiement automatique d'un cluster K8s
│   ├── main.tf
│   ├── variables.tf
│   └── modules/
│       ├── master/       # Nœud control-plane (kubeadm init + Calico)
│       └── worker/       # Nœuds workers (kubeadm join)
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

### nixos-kube

Étend `nixos-base` avec tout ce qu'il faut pour faire tourner un nœud Kubernetes :

- Modules kernel : `br_netfilter`, `overlay`, `ip_vs`, `wireguard`
- Paramètres sysctl pour le networking K8s
- `containerd` comme container runtime (CRI configuré, cgroups systemd)
- CNI plugins dans `/opt/cni/bin` (répertoire inscriptible pour Cilium/Calico)
- Packages : `kubectl`, `kubernetes`, `helm`, `cri-tools`, `conntrack-tools`, etc.
- `kubelet` en unité systemd compatible kubeadm (NixOS read-only oblige)
- Ports firewall ouverts pour le control-plane, kubelet, BGP et VXLAN

## Workflow — construire et uploader une image

### 1. Builder

```bash
make build-base   # → export/nixos-base.qcow2
make build-kube   # → export/nixos-kube.qcow2
```

### 2. Uploader vers Proxmox

```bash
make upload-base  # build + scp vers /var/lib/vz/images/ sur le nœud Proxmox
make upload-kube
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

Terraform déploie un cluster kubeadm complet (1 master + N workers) sur Proxmox en partant du template `nixos-kube`.

**Prérequis :** l'image `nixos-kube.qcow2` doit être uploadée sur Proxmox et le template créé au préalable.

### Configuration

Copier et adapter `terraform.tfvars` :

```hcl
proxmox_api_url    = "https://<proxmox>:8006/api2/json"
proxmox_user       = "terraform@pve"
proxmox_token_name = "terraform"
proxmox_token      = "<token>"

nixos_image_file_id = "local:iso/nixos-kube.qcow2"

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

1. Crée la VM master depuis le template, lui injecte un cloud-init qui :
   - Lance `kubeadm init` avec le CIDR configuré
   - Installe Calico comme CNI
   - Génère le `kubeadm join` command et l'expose via un mini serveur HTTP (port 9999, TTL 1h)
   - Copie le kubeconfig dans `~/kubeconfig`
2. Crée N VMs worker, chacune récupère le join-command depuis le master (retry toutes les 15s pendant 10 min) et rejoint le cluster

### Récupérer le kubeconfig

```bash
scp user@<master-ip>:~/kubeconfig ~/.kube/config
```

## Détails techniques

### Hostname sous NixOS + cloud-init

NixOS réapplique `networking.hostName` à chaque boot, écrasant ce que cloud-init a défini. Le service `cloud-hostname-restore` contourne ce problème en lisant le hostname écrit par cloud-init dans `/var/lib/cloud-hostname` et en le réappliquant après l'activation NixOS.

### kubelet et NixOS read-only

kubeadm s'attend à pouvoir écrire un drop-in dans `/etc/systemd/system/`. Ce répertoire est en lecture seule sur NixOS. L'unité kubelet définie dans `k8s.nix` hard-code les flags que kubeadm y mettrait normalement, et lit `kubeadm-flags.env` via `EnvironmentFile`. kubelet crashe en boucle jusqu'à ce que kubeadm ait écrit `/var/lib/kubelet/config.yaml` — c'est le comportement attendu, `Restart=always` gère ça.
