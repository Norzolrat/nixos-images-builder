# nix/ — définition de l'image

Ces fichiers servent **deux fois** : au build du qcow2 via `flake.nix`, et à
l'intérieur de la VM déployée, où Terraform les recopie dans `/etc/nixos/` pour que
`nixos-rebuild switch` fonctionne. Une modification ici a donc deux chemins d'effet.

## Avant de modifier

- **`machine.nix` est un placeholder.** Il est écrasé au premier boot par le fichier
  généré depuis `../terraform/modules/master/templates/machine.nix.tpl`. Y écrire
  quoi que ce soit d'utile ne sert à rien. Hostname, IP, VLANs : c'est le template.
- **Une seule image est construite** : `nixos-k8s-gpu-amd`. `flake.nix` expose encore
  `nixos-base`, `nixos-k8s` et `nixos-gpu-amd`, mais aucune cible make ne les
  construit et rien ne les déploie.
- **Une modif n'atteint pas les VMs existantes.** Il faut rebuilder l'image, la
  réuploader, recréer le template Proxmox — ou compter sur le `nixos-rebuild switch`
  du prochain déploiement, puisque ces fichiers sont réinjectés à chaque fois.

## Répartition

| Fichier | Contenu |
|---|---|
| `configuration.nix` | Base : cloud-init, SSH, fish, sudo, skeletons, services de hostname et de nettoyage template |
| `k8s.nix` | containerd, kubelet, CNI, sysctls, firewall |
| `gpu-amd.nix` | amdgpu, ROCm, groupes `render`/`video` |
| `hardware-image.nix` | filesystems (labels `nixos`/`ESP`) + bootloader |
| `machine.nix` | placeholder, écrasé au déploiement |

## Contraintes NixOS à ne pas casser

**`hardware-image.nix` sert au build ET dans la VM.** `make-disk-image` a besoin des
déclarations de filesystems, et `nixos-rebuild` dans la VM aussi — sans lui,
assertions manquantes sur `fileSystems."/"` et le bootloader, parce que `flake.nix`
n'est jamais copié sur la VM.

**L'unité kubelet est écrite à la main** (`services.kubernetes.kubelet.enable` est
forcé à `false`). kubeadm veut poser un drop-in dans `/etc/systemd/system/`, qui est
en lecture seule sur NixOS ; les flags équivalents sont donc hard-codés. Deux
conséquences : pas de `wantedBy` (c'est kubeadm qui démarre kubelet), et un crash-loop
normal au premier boot jusqu'à ce que `/var/lib/kubelet/config.yaml` existe.

**`/opt/cni/bin` doit rester un vrai répertoire inscriptible**, peuplé par copie via
le service `cni-plugins-install`. Un lien symbolique vers le store est en lecture
seule et fait échouer les init-containers de certains CNI.

**`nix.nixPath` pointe sur le nixpkgs embarqué** dans l'image. C'est ce qui permet à
`nixos-rebuild switch` de fonctionner dans la VM sans accès internet. Ne pas le
retirer.

**Le hostname est restauré par un service dédié.** NixOS réapplique
`networking.hostName` à chaque boot ; `cloud-hostname-restore` relit
`/var/lib/cloud-hostname` après l'activation pour rendre la main à cloud-init.

**`net.ifnames=0`** est posé dans `k8s.nix` et dans le `machine.nix` généré. C'est ce
qui garantit `eth0`/`eth1` — le réseau et MetalLB en dépendent, voir
[../docs/reseau.md](../docs/reseau.md).

## Ports

Le firewall est déclaré dans `k8s.nix`. **Un service exposé sur un nouveau port doit
y être ajouté** — l'IP de VLAN ne contourne pas le pare-feu du nœud.
