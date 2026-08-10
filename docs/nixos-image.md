# L'image NixOS

Comment l'image est construite, et les contorsions que NixOS impose pour faire
tourner kubeadm.

## Le flake

[nix/flake.nix](../nix/flake.nix) épingle `nixpkgs` sur `nixos-25.11` et expose deux
familles de sorties à partir des mêmes listes de modules :

- `nixosConfigurations.*` — des systèmes NixOS classiques, sans image disque ;
- `packages.x86_64-linux.*` — les qcow2, produits en passant la configuration à
  `make-disk-image.nix` (format qcow2, table de partition EFI, taille auto).

Quatre combinaisons sont déclarées (`nixos-base`, `nixos-k8s`, `nixos-gpu-amd`,
`nixos-k8s-gpu-amd`) mais **une seule est utilisée** : `nixos-k8s-gpu-amd`, la seule
qu'une cible make construit. Les trois autres sont des vestiges.

## Composition

```
configuration.nix          base commune
├── machine.nix            placeholder, écrasé au déploiement
└── hardware-image.nix     filesystems + bootloader
k8s.nix                    containerd, kubelet, CNI, firewall
gpu-amd.nix                amdgpu, ROCm
```

`configuration.nix` importe `machine.nix` et `hardware-image.nix`. `k8s.nix` et
`gpu-amd.nix` sont ajoutés par le flake au build — et réimportés dans la VM par le
`machine.nix` généré, puisque `flake.nix` n'y est jamais copié.

## Double usage des fichiers

C'est le point le moins intuitif du repo. Les mêmes `.nix` servent :

1. **au build**, via le flake, pour produire le qcow2 ;
2. **dans la VM**, où Terraform les injecte en base64 dans `/etc/nixos/` via
   cloud-init, pour que `nixos-rebuild switch` fonctionne.

Le second usage explique plusieurs choix : `hardware-image.nix` déclare les
filesystems (sans lui, `nixos-rebuild` échoue sur des assertions manquantes), le
`machine.nix` généré réimporte explicitement `k8s.nix` et `gpu-amd.nix` (sinon un
rebuild dans la VM basculerait vers une configuration sans containerd ni kubelet), et
`nix.nixPath` pointe sur le nixpkgs embarqué (pour rebuilder sans accès internet).

## Ce que NixOS impose

**kubelet écrit à la main.** kubeadm veut déposer un drop-in systemd dans
`/etc/systemd/system/`, impossible sur NixOS où il vient du store en lecture seule.
`services.kubernetes.kubelet.enable` est donc forcé à `false` et une unité `kubelet`
est déclarée avec les flags que kubeadm aurait posés, plus un
`EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env` que kubeadm remplit au `init`.

L'unité n'a **pas de `wantedBy`** : c'est kubeadm qui démarre et arrête kubelet.
Au premier boot, kubelet crash-loope jusqu'à ce que `kubeadm init` ait écrit
`/var/lib/kubelet/config.yaml` — `Restart=always` et `RestartSec=10` absorbent la
période. Ce n'est pas une panne.

**`/opt/cni/bin` en vrai répertoire.** kubeadm et les CNI attendent ce chemin FHS.
Un lien vers le store serait en lecture seule, or certains CNI y déposent leurs
propres binaires. Le service `cni-plugins-install` copie donc les plugins dedans au
boot (`cp -n`, non destructif).

**`/usr/bin/kubelet`** est créé en lien via `systemd.tmpfiles`, parce que kubeadm
cherche ce chemin en dur.

**Le hostname doit être restauré.** NixOS réapplique `networking.hostName` à chaque
boot, écrasant ce que cloud-init a posé. Le service `cloud-hostname-restore` relit
`/var/lib/cloud-hostname` après l'activation.

**Pas de swap.** `swapDevices` est forcé à vide et `zramSwap` désactivé — kubelet
refuse de démarrer avec du swap actif sans configuration explicite.

## Cycle de vie du template

`cloud-init-clean` est une unité déclenchée au shutdown, mais uniquement si le fichier
`/var/lib/cloud/clean-on-shutdown` existe. Elle lance `cloud-init clean --logs`, retire
le hostname persisté et vide `/etc/machine-id` pour que chaque clone en génère un
unique. C'est ce que `make prepare-template` déclenche à distance avant d'éteindre la
VM.

Sans cette purge, tous les clones du template héritent du cache cloud-init de la VM
d'origine et ne se reconfigurent pas.

## Confort intégré

Le shell par défaut est fish, avec un prompt et des alias (`k`, `ll`, `g`) déposés via
`/etc/skel` — donc appliqués à tout user créé par cloud-init. Le user par défaut est
mis dans `wheel` avec sudo sans mot de passe, via un fragment
`cloud/cloud.cfg.d/`. `gpu-amd.nix` surcharge ce fragment pour y ajouter `render` et
`video`.
