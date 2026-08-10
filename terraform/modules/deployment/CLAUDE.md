# modules/deployment — les charges Kubernetes

Sept sous-modules, chacun dans son namespace. `main.tf` ne fait que les composer et
leur passer des variables.

| Module (nom `MODULE=`) | Répertoire | Namespace | Expose sur |
|---|---|---|---|
| `metallb` | `metallb/` | `metallb-system` | — |
| `traefik` | `traefik/` | `traefik` | VLAN dmz + IP mgmt |
| `cloudflare` | `cloudflare/` | `cloudflare` | sortant seulement |
| `hello` | `hello/` | `hello-world` | VLAN ai |
| `perso` | `perso/` | `perso` | VLAN perso |
| `management` | `management/` | `management` | VLAN mgmt |
| `llm_stack` | `llm-stack/` | `llm` | VLAN ai |

Attention au nom : `llm_stack` avec underscore pour `make deploy-module`, alors que
le répertoire est `llm-stack` avec un tiret.

## Comment un service est exposé

**Le pattern majoritaire n'est pas MetalLB.** La plupart des services sont des
`ClusterIP` avec `external_ips = [<IP du VLAN>]` : le nœud porte déjà cette IP sur sa
subinterface, kube-proxy accepte le trafic qui lui est destiné.

Conséquence directe : **sur un VLAN donné, tous les services partagent la même IP,
donc leurs ports doivent être distincts**. Le VLAN `ai` en a déjà quatre sur
`10.0.10.200`. Avant d'ajouter un service, vérifier les ports pris :

```bash
grep -rn 'port *=' modules/<stack>/main.tf
```

Seul Traefik utilise un vrai `LoadBalancer`, avec l'annotation
`metallb.universe.tf/loadBalancerIPs`. Voir [../../../docs/reseau.md](../../../docs/reseau.md).

## Ajouter une stack

1. Créer `modules/<nom>/` avec `main.tf`, `variables.tf`, `outputs.tf`.
2. Déclarer un `kubernetes_namespace_v1` dédié.
3. Choisir le VLAN d'exposition et **un port libre** sur son IP.
4. Ajouter le bloc `module` dans `main.tf`.
5. Remonter chaque variable sur trois niveaux : `../../variables.tf` (racine) →
   `main.tf` → `variables.tf` (ici) → `modules/<nom>/variables.tf`. Oublier un
   maillon donne une erreur d'attribut inconnu peu lisible.
6. Si le service écoute sur un port non déjà ouvert, **l'ajouter au firewall** dans
   [`../../../nix/k8s.nix`](../../../nix/k8s.nix) — ce qui impose un rebuild d'image
   ou un `nixos-rebuild` dans la VM.
7. Déployer seul : `make deploy-module MODULE=<nom>`.

## Persistance

Les données vivent sur le nœud en `hostPath`, aux chemins passés par les variables
`*_host_data_path` (`/opt/traefik-acme`, `/opt/teleport`, `/opt/perso`, `/opt/llm`).
Elles survivent à un `deploy-module-destroy`, mais **pas** à la destruction de la VM :
il n'y a ni sauvegarde ni stockage externe.

## Ordre

`metallb` doit exister avant tout service `LoadBalancer` — donc avant `traefik`.
Terraform déduit l'ordre des références entre ressources, mais un
`deploy-module-destroy MODULE=metallb` isolé laisserait Traefik sans IP.

## Secrets

Plusieurs stacks reçoivent des secrets en variables (mots de passe Postgres, clé GPG
Passbolt, tokens). Ils viennent de `terraform.tfvars`, gitignoré, et finissent dans
des `kubernetes_secret_v1`. Ne jamais les afficher ni les écrire en dur dans un
`main.tf`.
