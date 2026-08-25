# terraform/ — root module

Un seul root module. `modules/master` crée la VM Proxmox, `modules/deployment`
applique les charges Kubernetes, et quatre `null_resource` font la jonction.

## La règle qui casse tout si on l'ignore

**Ne jamais lancer `terraform apply` nu sur un cluster qui n'existe pas.** Les
providers `kubernetes` et `helm` lisent `./output/kubeconfig` au démarrage du plan,
avant qu'une seule ressource soit créée. Sans cluster, le plan échoue.

L'apply se fait en deux passes, encodées dans les cibles make :

```bash
make deploy          # passe 1 (ciblée) puis passe 2 (complète)
make deploy-cluster  # passe 1 seule
```

La passe 1 cible `module.master` et les quatre `null_resource`. Détail et raison :
[../docs/architecture.md](../docs/architecture.md#pourquoi-deux-passes).

Même logique à la destruction : `make deploy-destroy` retire `module.deployment` du
state *avant* de détruire le master, sinon le plan final ne peut pas aboutir.

## Secrets

`terraform.tfvars` contient en clair le token API Proxmox, le token Cloudflare, une
clé GPG privée et plusieurs mots de passe. Il est gitignoré. **Ne jamais l'afficher,
le recopier dans un message, ni le commiter.** Même chose pour `terraform.tfstate` et
`output/kubeconfig`. Inventaire : [../docs/secrets.md](../docs/secrets.md).

## State

Local, sans backend distant ni verrou : `terraform.tfstate`, gitignoré. Un seul
exemplaire, sur cette machine. Le sauvegarder avant tout `state rm`, `import` ou
manipulation manuelle.

## Cibler une seule stack

```bash
make deploy-list                     # modules disponibles et ceux dans le state
make deploy-module MODULE=llm_stack
```

Le nom est celui du bloc `module` dans `modules/deployment/main.tf`, pas celui du
répertoire : `llm_stack` (underscore) pour `modules/llm-stack/` (tiret).

Le [Makefile local](Makefile) offre les mêmes opérations en interactif (sans
`-auto-approve`), utile quand on veut relire un plan avant de l'appliquer.

## Pièges

**Chemins relatifs.** `modules/master/main.tf` lit les sources NixOS via
`${path.root}/../nix/...`. Les cibles make font toutes un `cd terraform` d'abord —
lancer terraform depuis un autre répertoire casse ces chemins.

**Outputs absents du state.** `master_vm_ip` a été ajouté à `outputs.tf` après le
dernier apply : `terraform output -raw master_vm_ip` échoue tant qu'un apply complet
n'a pas eu lieu. C'est attendu, pas un bug de configuration.

## Ajouter une variable

Trois niveaux à traverser, dans cet ordre : `variables.tf` (racine) →
passage dans le bloc `module` de `main.tf` → `modules/deployment/variables.tf` →
passage dans le sous-module → `modules/deployment/modules/<stack>/variables.tf`.
Oublier un maillon donne une erreur d'attribut inconnu peu explicite.
