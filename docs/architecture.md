# Architecture

Comment on passe d'un fichier `.nix` à des pods qui tournent.

## La chaîne

```
nix/flake.nix
    │  nix build → make-disk-image
    ▼
export/nixos-k8s-gpu-amd.qcow2          (~5,4 Go)
    │  scp
    ▼
Proxmox /var/lib/vz/import/images/0/
    │  clone en disque de VM (nixos_image_file_id)
    ▼
VM master  ──cloud-init──▶  nixos-rebuild  ──▶  kubeadm init + Calico
    │
    │  scp ~/kubeconfig
    ▼
terraform/output/kubeconfig
    │  providers kubernetes + helm
    ▼
module.deployment  →  MetalLB, Traefik, perso, management, llm-stack, ...
```

## Les deux modules Terraform

Le root module [terraform/main.tf](../terraform/main.tf) orchestre deux blocs :

**`modules/master`** crée la VM Proxmox : clone du qcow2, OVMF + q35, deux cartes
réseau (management + trunk), et un `hostpci` optionnel pour le GPU. Il uploade aussi
le snippet cloud-init sur Proxmox, qui porte toute la logique de bootstrap.

**`modules/deployment`** applique les charges Kubernetes. Il contient sept
sous-modules, chacun dans son namespace : `metallb`, `traefik`, `cloudflare`,
`hello`, `perso`, `management`, `llm_stack`. MetalLB doit passer en premier, les
autres exposent leurs services via des `LoadBalancer` qu'il alimente.

Entre les deux, quatre `null_resource` font la jonction : nettoyage du `known_hosts`
local, attente de la fin de cloud-init en SSH, récupération du kubeconfig par scp,
puis attente que l'API Kubernetes réponde (36 tentatives, 10 s d'intervalle).

## Pourquoi deux passes

Les providers `kubernetes` et `helm` sont configurés avec
`config_path = "./output/kubeconfig"` ([terraform/providers.tf](../terraform/providers.tf)).
Terraform initialise ses providers **au démarrage du plan**, pas au moment où les
ressources sont appliquées. Sur un cluster qui n'existe pas encore, le fichier est
absent ou périmé, et le plan échoue avant d'avoir créé quoi que ce soit.

D'où la séquence, encodée dans `make deploy` :

1. **Passe 1** — `terraform apply` ciblé sur `module.master` et les quatre
   `null_resource`. À la fin, `output/kubeconfig` existe et l'API répond.
2. **Passe 2** — `terraform apply` complet. Les providers lisent un kubeconfig
   valide, `module.deployment` peut être planifié.

C'est aussi pour ça que `make deploy-destroy` fait un `terraform state rm
module.deployment` avant de détruire le master : une fois la VM éteinte, plus aucun
plan touchant des ressources k8s ne peut aboutir.

## Ce que fait cloud-init sur la VM

Défini dans
[terraform/modules/master/templates/cloud-init-master.yml.tpl](../terraform/modules/master/templates/cloud-init-master.yml.tpl).

**`write_files`** dépose dans `/etc/nixos/` les sources NixOS encodées en base64 :
`configuration.nix`, `k8s.nix`, `gpu-amd.nix`, `hardware-image.nix`, et le
`machine.nix` généré par Terraform (hostname, timezone, IP statique, VLANs). Elles
sont copiées parce que `flake.nix` n'est jamais présent sur la VM : sans elles, un
`nixos-rebuild switch` à l'intérieur de la VM basculerait vers une configuration sans
containerd ni kubelet.

**`runcmd`** enchaîne ensuite :

1. Régénération du `machine-id` (figé dans l'image, donc identique sur tous les clones).
2. Régénération des clés SSH hôtes, pour éviter les collisions de `known_hosts`.
3. Renommage des NICs en `eth0` / `eth1` par position — insensible aux noms
   prédictifs `ens18`/`ens19`.
4. `nixos-rebuild switch`, qui applique `machine.nix` : IP statique, VLANs,
   systemd-networkd.
5. `/root/k8s-bootstrap.sh`.

**`k8s-bootstrap.sh`** applique le hostname, attend containerd, lance `kubeadm init`
(avec `--pod-network-cidr`, `--service-cidr=10.96.0.0/12` et l'IP du nœud en
`--apiserver-advertise-address`), copie le kubeconfig dans `~/kubeconfig` du user
par défaut, installe Calico — dont le manifeste est patché à la volée pour aligner le
pod CIDR — puis attend le rollout du daemonset.

Le cluster est mono-nœud : il n'y a plus de module `worker`, et le bootstrap ne
génère plus de `kubeadm join`.

## Pièges connus

**`NIX_PATH` absent dans `runcmd`.** La variable n'est exportée que par
`/etc/set-environment`, sourcé uniquement par les shells de login. Sans le
`source /etc/set-environment` explicite, `nixos-rebuild` échoue sur
`file 'nixpkgs/nixos' was not found in the Nix search path`, et `machine.nix`
(IP statique, VLANs) n'est jamais appliqué.

**Chemins absolus en `remote-exec`.** Une session SSH non interactive ne source pas
`/etc/set-environment` non plus : `/run/current-system/sw/bin` n'est pas dans le
`PATH`. Les commandes de `null_resource.wait_cloud_init` sont donc écrites en absolu.

**kubelet crashe en boucle au premier boot.** C'est attendu. Le drop-in que kubeadm
veut écrire dans `/etc/systemd/system/` est impossible sur NixOS (read-only), donc
[nix/k8s.nix](../nix/k8s.nix) hard-code les flags équivalents. kubelet redémarre en
boucle jusqu'à ce que `kubeadm init` ait écrit `/var/lib/kubelet/config.yaml` ;
`Restart=always` absorbe la période.

**`hardware-image.nix` sert deux fois.** Il déclare les filesystems (labels `nixos`
et `ESP`) et le bootloader, à la fois pour `make-disk-image` au build et pour que
`nixos-rebuild` fonctionne dans la VM. Le retirer casse les deux.

## Versions épinglées

| Composant | Version | Où |
|---|---|---|
| nixpkgs | `nixos-25.11` | [nix/flake.nix](../nix/flake.nix) |
| Calico | `3.29.3` | variable `calico_version` |
| MetalLB | `0.14.9` | en dur dans [terraform/main.tf](../terraform/main.tf) |
| pod CIDR | `10.244.0.0/16` | variable `pod_network_cidr` |
| service CIDR | `10.96.0.0/12` | en dur dans le script de bootstrap |
