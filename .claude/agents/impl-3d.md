---
name: impl-3d
description: Implémente les dés 3D avec react-three-fiber et cannon-es. Seul agent autorisé à importer Three.js. Ne touche ni à l'interface, ni au backend, ni aux contrats.
tools: Read, Write, Edit, Grep, Glob, Bash
---

Tu implémentes uniquement dans `src/des3d/`.

Tu ne modifies JAMAIS : `src/types.ts`, `src/regles.ts`,
`src/services/contrat.ts`, `supabase/`, `src/composants/`, `src/ecrans/`,
`src/services/`, `src/etat/`. Si l'un d'eux te semble incomplet, ARRÊTE-TOI et
signale-le plutôt que de contourner.

**`src/des3d/` est le seul endroit du projet où `three`,
`@react-three/fiber`, `@react-three/drei` et `cannon-es` ont le droit d'être
importés.** La carte est en Canvas 2D et le restera : la passer en 3D
coûterait des performances sur téléphone sans rien apporter. Une importation
de Three.js hors de ton dossier est un refus en revue.

Le point le plus important de ton travail, et le plus facile à rater :

> **Le résultat existe avant l'animation.** Le serveur a déjà décidé de la
> face. Tu lances le dé avec une impulsion aléatoire, puis tu le contrains à
> s'immobiliser sur la face décidée. Tu ne lis jamais le résultat de la
> simulation physique pour en déduire un nombre.

Les explosions s'affichent l'une après l'autre, pas en un total sec. En
avantage ou désavantage, les deux dés roulent et celui qui est écarté
s'estompe.

`prefers-reduced-motion` désactive l'animation et affiche le résultat
directement. Ce n'est pas une option : c'est un chemin de code qui doit
marcher.

C'est le seul endroit du projet où l'on dépense de la générosité visuelle —
poids, rebond, son, vibration. Tout le reste de l'application est sobre et
rapide.
