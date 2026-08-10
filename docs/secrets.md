# Secrets

## Règle

Trois fichiers contiennent des secrets exploitables et ne doivent **jamais** être
affichés, recopiés dans un message, ni commités :

| Fichier | Contenu |
|---|---|
| `terraform/terraform.tfvars` | tous les secrets d'entrée, en clair |
| `terraform/terraform.tfstate` | les mêmes, plus tout ce que les providers ont enregistré |
| `terraform/output/kubeconfig` | certificat client admin du cluster |

Les trois sont gitignorés — vérifié : `git ls-files` ne les liste pas. Le `.gitignore`
de `terraform/` couvre aussi `*.auto.tfvars`, `secrets.tfvars`, `prod.tfvars`.

Ne pas les ouvrir « pour vérifier » : leur contenu se retrouverait dans un log de
session ou un historique de conversation, hors du périmètre protégé par git.

## Inventaire

Variables marquées `sensitive` dans [terraform/variables.tf](../terraform/variables.tf) :

**Infrastructure**
- `proxmox_token_name`, `proxmox_token` — token API Proxmox
- `proxmox_ssh_private_key_path` — chemin de la clé SSH du nœud Proxmox
- `manager_ssh_public_key` — clé publique déployée sur les VMs

**Réseau et exposition**
- `cloudflare_tunnel_token` — tunnel Zero Trust
- `traefik_cloudflare_api_token` — DNS-01 pour ACME, permission `Zone:DNS:Edit`
- `traefik_dashboard_htpasswd` — accès au dashboard Traefik

**Applications**
- `coder_postgres_password`, `perso_postgres_password` — bases Postgres
- `perso_passbolt_gpg_private_key` — clé GPG privée du serveur Passbolt
- `perso_ghostfolio_secret`, `llm_searxng_secret_key` — clés applicatives

Plusieurs ont une valeur par défaut du type `changeme-replace-with-...`. Un
déploiement qui part avec ces défauts expose des services avec des secrets publics :
à vérifier avant tout premier apply.

## Où ils finissent

`terraform.tfvars` → variables Terraform → `kubernetes_secret_v1` dans le cluster, et
au passage dans `terraform.tfstate` **en clair**. Un state Terraform n'est pas un
coffre : il a la même sensibilité que le fichier de variables.

Le kubeconfig est récupéré par scp depuis la VM vers `terraform/output/`. Il porte un
certificat client `cluster-admin` sans expiration courte — quiconque l'obtient a le
cluster entier.

## Rotation

Il n'y a aucun mécanisme de rotation automatique. Changer un secret impose de mettre à
jour `terraform.tfvars` puis de réappliquer la stack concernée :

```bash
make deploy-module MODULE=<stack>
```

Le `terraform.tfstate` conservera la valeur précédente dans son historique de version
si un backup existe (`terraform.tfstate.backup`). Un secret réellement compromis doit
être révoqué à la source (Cloudflare, Proxmox, Postgres), pas seulement remplacé ici.

## Ce qui n'est pas protégé

- **Pas de chiffrement au repos** du state ni des tfvars : ce sont des fichiers en
  clair sur la machine de déploiement.
- **Pas de backend distant, donc pas de verrou** : deux applies simultanés peuvent
  corrompre le state.
- **Les données applicatives** en `hostPath` sur le nœud (`/opt/perso`, `/opt/llm`,
  ...) ne sont ni chiffrées ni sauvegardées.

Ces choix sont cohérents avec un usage personnel mono-nœud. Ils deviendraient
problématiques dès que la machine de déploiement est partagée.
