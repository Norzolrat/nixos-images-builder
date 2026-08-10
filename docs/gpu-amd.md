# GPU AMD

Le nœud reçoit une carte AMD en passthrough PCIe. C'est la partie la plus fragile du
déploiement.

## Le reset bug

Une carte AMD peut rester dans un état bloqué après un reset raté — typiquement quand
une VM est détruite sans que la carte soit réinitialisée proprement. Elle fige alors
**OVMF avant même le boot** du système : la VM démarre sans écran, sans réseau, sans
agent QEMU. Terraform attend le SSH jusqu'au timeout de 20 minutes sans jamais rien
obtenir, et le diagnostic ressemble à un problème réseau alors qu'il n'y en a pas.

Deux garde-fous existent :

**`gpu_rombar = false`** (le défaut). Le firmware n'exécute pas la vBIOS au démarrage,
ce qui évite le gel UEFI quand la carte sort d'un reset raté.

**`enable_gpu_passthrough = false`** retire complètement le bloc `hostpci` de la VM,
qui démarre alors normalement :

```bash
make deploy GPU=false
```

C'est le premier réflexe quand une VM ne répond pas après un déploiement : redéployer
sans la carte pour distinguer un problème de GPU d'un problème de configuration. Un
reboot de l'hôte Proxmox est généralement nécessaire pour débloquer la carte.

## Configuration Proxmox

Le passthrough passe par un **resource mapping** déclaré côté Proxmox
(`Datacenter → Resource Mappings → PCI Devices`), pas par un ID PCI en dur. Le nom du
mapping est la variable `gpu_pci_mapping`, `amd-gpu` par défaut.

Le mapping doit exister avant le déploiement, sinon l'apply échoue à la création de la
VM. Terraform ne le crée pas.

Côté VM, le bloc est conditionnel — voir la ressource `hostpci` dans
[terraform/modules/master/main.tf](../terraform/modules/master/main.tf) :

```hcl
dynamic "hostpci" {
  for_each = var.enable_gpu ? [1] : []
  ...
}
```

## Côté NixOS

[nix/gpu-amd.nix](../nix/gpu-amd.nix) fournit :

- le module `amdgpu` en initrd et en kernel module ;
- `hardware.enableRedistributableFirmware`, **obligatoire pour Navi 48 / RDNA 4** ;
- la stack graphique avec `rocmPackages.clr.icd` pour OpenCL ;
- des règles udev donnant au groupe `render` l'accès à `/dev/kfd` et aux nœuds
  `renderD*` ;
- un fragment cloud-init qui place le user par défaut dans `wheel`, `render` et
  `video` — sans ça, aucun accès GPU sans root ;
- `rocm-smi` et `rocminfo` pour diagnostiquer.

## Vérifier que la carte est vue

Depuis la VM :

```bash
rocm-smi     # la carte est-elle détectée ?
rocminfo     # quelle architecture gfx ?
ls -l /dev/kfd /dev/dri/renderD*
```

Si `/dev/kfd` existe mais est inaccessible sans `sudo`, le user n'est pas dans le
groupe `render` — le fragment cloud-init n'a pas été appliqué, ce qui arrive si le
`nixos-rebuild switch` du bootstrap a échoué. Vérifier `/root/nixos-rebuild.log` sur
la VM.

## Charges qui l'utilisent

La stack `llm_stack` (Ollama, Open-WebUI, et ComfyUI si `llm_enable_comfyui`) est la
consommatrice prévue. Les pods ont besoin d'accéder à `/dev/kfd` et `/dev/dri` — un
déploiement fait avec `GPU=false` les laissera tourner en CPU ou échouer selon
l'image.
