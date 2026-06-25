# 4. Modèle d'automerge piloté par type de mise à jour (trusted + denylist)

Date : 2026-06-25

## Statut

Accepté

## Contexte

Autoriser un package/gem à l'automerge était devenu complexe et coûteux à maintenir.

La logique d'« autorisation » (rendre un package éligible à `automerge: true`) était éclatée entre plusieurs presets, avec des modèles opposés selon l'écosystème :

- `preset/automergeRecommendedNPM.json` : une **allowlist npm géante** (~35 entrées) qu'il fallait éditer à la main pour chaque nouveau package, avec des doublons (`date-fns`, `lucide-react-native`), plusieurs sous-listes et des catch-all redondants.
- `preset/automergeRecommendedGems.json` : à l'inverse, une **denylist** (tout en minor/patch sauf quelques exceptions).
- `preset/suspectNPMDependencies.json` : un garde-fou qui n'était **branché nulle part**, donc inactif.
- `recommended.json` : encore d'autres règles d'automerge (catégories, docker, asdf, npm patch) chevauchant les presets.

Conséquence : pour « autoriser » un package, il fallait savoir quel fichier éditer, quelle sous-liste choisir, et le comportement npm/gems n'était pas cohérent.

## Décision

Nous décidons de raisonner **par type de mise à jour**, et non par écosystème, et de centraliser la logique dans trois presets clairs :

- **patch / digest** → automerge par défaut, partout (`preset/automergeDefaults.json`). Aucune liste à maintenir.
- **minor** → automerge par défaut pour `npm` et `bundler` (`preset/automergeDefaults.json`). Pour exclure un package risqué : une ligne dans la **denylist** (`preset/automergeDenylist.json`).
- **major** → jamais par défaut. Pour en autoriser un : une entrée dans l'**allowlist** (`preset/automergeTrustedMajors.json`), avec contrainte de version si besoin.

Le câblage se fait dans `preset/automergeBase.json`, où l'ordre d'extension définit la précédence (la dernière règle gagne) :

1. `automergeDefaults` (défauts patch/minor)
2. `automergeTrustedMajors` (opt-in des majors)
3. `automergeToolVersions`
4. `automergeDenylist` (exclusions, appliquées en dernier)

Le filet de sécurité reste la **CI** : `platformAutomerge` ne déclenche le merge automatique que lorsque les checks passent.

Les anciens presets `automergeRecommendedNPM`, `automergeRecommendedGems`, `automergePatches`, `automergeTest` et `suspectNPMDependencies` sont supprimés. Le cas `rails` reste géré par `preset/groupRails.json`.

## Conséquences

### Points positifs

- **Autoriser un package = 0 ligne dans la grande majorité des cas** : un nouveau package en patch/minor est automergé par défaut.
- **Deux petites listes stables seulement** : `automergeTrustedMajors` (majors de confiance) et `automergeDenylist` (exclusions). Un test unitaire garde contre les doublons.
- **Cohérence npm/gems** : même modèle pour les deux écosystèmes.
- **Garde-fous réactivés** : les règles `axios` et `react-native-signature-canvas`, auparavant mortes, sont désormais effectives via la denylist.

### Points négatifs / risques

- **Élargissement du comportement npm** : les mises à jour **minor de dépendances de prod** npm s'automergent désormais par défaut (auparavant il fallait les lister). On s'appuie sur la CI comme garde-fou.

### Point ouvert

`applicationLegacy.json` hérite de l'automerge via `base.json` malgré sa description « No automerge ». Ce comportement préexistant n'est pas modifié par cet ADR ; déplacer les presets d'automerge de `base` vers `recommended` pourra être traité séparément.
