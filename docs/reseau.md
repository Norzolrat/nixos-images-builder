# Réseau

Le nœud a deux cartes : une pour l'administration, une en trunk qui porte tous les
VLANs applicatifs.

## Interfaces

| Interface | Bridge Proxmox | Adresse | Rôle |
|---|---|---|---|
| `eth0` | `network_bridge` (défaut `mgmt`) | `vm_ip`, statique | Administration, SSH, API Kubernetes |
| `eth1` | `trunk_bridge` (défaut `vmbr1`) | aucune | Trunk : porte les VLANs taggés |
| `eth1.<id>` | — | une IP par VLAN | Exposition des services |

Valeurs actuelles côté management : `10.255.255.54/24`, passerelle
`10.255.255.254`. L'API Kubernetes écoute sur cette IP (`kubeadm init` reçoit
`--apiserver-advertise-address` = IP du nœud).

Les noms `eth0` / `eth1` ne sont pas ceux que Proxmox produit spontanément
(`ens18`, `ens19`). Deux mécanismes les garantissent : `net.ifnames=0` en paramètre
kernel dans `machine.nix`, et un renommage par position dans le `runcmd` cloud-init
au tout premier boot, avant que quoi que ce soit ne dépende du nom.

L'ordre compte : `eth0` est la **première** carte déclarée dans la VM, `eth1` la
seconde. Inverser les blocs `network_device` dans
[terraform/modules/master/main.tf](../terraform/modules/master/main.tf) inverserait
management et trunk.

## Plan VLAN

Défini par `vlan_subinterfaces` dans `terraform.tfvars` :

| VLAN | ID | IP du nœud | Usage |
|---|---|---|---|
| `dmz` | 15 | `10.0.15.200/24` | Traefik, entrée HTTP/HTTPS |
| `obs` | 2 | `10.0.2.200/24` | Observabilité |
| `perso` | 5 | `10.0.5.200/24` | Stack perso (Passbolt, Affine, Ghostfolio, ...) |
| `ai` | 10 | `10.0.10.200/24` | Stack LLM (Ollama, Open-WebUI, ...) |

Ajouter un VLAN = ajouter une entrée dans cette liste. Elle alimente trois choses
d'un coup : les subinterfaces systemd-networkd via `machine.nix.tpl`, les pools
MetalLB, et les `L2Advertisement`. Aucune autre modification n'est nécessaire côté
Terraform — mais le VLAN doit exister et être taggé sur le bridge trunk Proxmox.

## Qui configure quoi

Au premier boot, cloud-init pose l'IP de management (via l'`ip_config` Proxmox). Puis
`nixos-rebuild switch` applique `machine.nix`, qui bascule tout sur
**systemd-networkd** : `eth0` statique, `eth1` en parent VLAN sans IP, une `netdev`
et un `network` par subinterface.

À partir de là, `services.cloud-init.network.enable` est forcé à `false`. C'est
délibéré : sans ça, cloud-init réécrirait la configuration réseau au boot suivant et
écraserait les VLANs. Conséquence pratique : **changer l'IP dans Proxmox ne suffit
plus** une fois la VM déployée, c'est `machine.nix.tpl` qui fait autorité.

## Exposer un service

Deux mécanismes coexistent dans ce repo, et un seul passe par MetalLB.

**`external_ips` — le cas majoritaire.** La quasi-totalité des services sont des
`ClusterIP` avec `external_ips = [<IP du VLAN>]`. kube-proxy accepte alors le trafic
destiné à cette IP, que le nœud porte déjà sur sa subinterface. MetalLB n'intervient
pas du tout.

La conséquence est la contrainte la plus importante de ce cluster : sur un VLAN
donné, **tous les services partagent une seule et même IP, donc leurs ports doivent
être distincts**. Le VLAN `ai` héberge quatre services sur `10.0.10.200`, le VLAN
`perso` trois sur `10.0.5.200`. Vérifier les ports déjà pris avant d'en ajouter un.

**`LoadBalancer` + MetalLB — un seul service.** Traefik, via l'annotation
`metallb.universe.tf/loadBalancerIPs` pointant sur l'IP DMZ. Il déclare en plus
`external_ips = [mgmt_ip]` pour rester joignable depuis le réseau de management, qui
est la cible du NAT côté pare-feu.

## MetalLB

Installé par Helm dans `metallb-system`, en mode **L2** (pas de BGP).

Pour chaque VLAN, [le module metallb](../terraform/modules/deployment/modules/metallb/main.tf)
crée une paire :

- un `IPAddressPool` contenant **exactement l'IP du nœud sur ce VLAN, en /32** ;
- un `L2Advertisement` lié à cette pool et restreint à l'interface `eth1.<id>`.

Chaque VLAN n'offre donc qu'une seule IP allouable. Ça suffit aujourd'hui puisque
seul Traefik en consomme une, mais un second service `LoadBalancer` sur le VLAN
`dmz` resterait en `<pending>` : il faudrait élargir la plage de la pool.

## Plages internes au cluster

| Plage | Valeur | Défini où |
|---|---|---|
| Pods | `10.244.0.0/16` | `pod_network_cidr`, passé à kubeadm et injecté dans le manifeste Calico |
| Services | `10.96.0.0/12` | en dur dans le script de bootstrap cloud-init |

Le manifeste Calico est téléchargé depuis GitHub au boot puis patché par `sed` pour
remplacer son `192.168.0.0/16` par `pod_network_cidr`. Changer le CIDR des pods dans
les variables suffit donc, mais impose de redéployer la VM — ce n'est pas modifiable
sur un cluster vivant.

## Pare-feu

Le firewall NixOS est actif sur le nœud ([nix/k8s.nix](../nix/k8s.nix)), avec
`checkReversePath = "loose"` — nécessaire avec plusieurs interfaces et le routage du
CNI. Ports ouverts :

| Ports | Pour |
|---|---|
| 22 | SSH |
| 6443, 2379-2380, 10250, 10257, 10259 | control-plane, etcd, kubelet |
| 179, 5473, UDP 4789 | Calico : BGP, Typha, VXLAN |
| 80, 443, 8080 | Traefik |
| 3023, 3024, 3026 | Teleport |
| 30000, 9999 | NodePort, serveur de join-command |

Un service exposé qui ne répond pas alors que MetalLB lui a bien donné une IP mérite
un coup d'œil à cette liste avant tout le reste : **un port applicatif nouveau doit y
être ajouté explicitement**, l'IP MetalLB ne contourne pas le firewall du nœud.

## Accès depuis l'extérieur

Deux chemins coexistent :

- **Traefik** sur l'IP DMZ, avec ACME/Let's Encrypt en DNS-01 via Cloudflare. C'est
  la cible d'un NAT depuis le pare-feu, d'où la variable `traefik_mgmt_ip`.
- **Cloudflare Tunnel** (`cloudflared`), qui sort du cluster sans port entrant. Le
  tunnel n'est déployé que si `cloudflare_tunnel_token` est renseigné.
