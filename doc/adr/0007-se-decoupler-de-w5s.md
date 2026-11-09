# 7. Se découpler de w5s/renovate-config

Date : 2026-11-09

## Statut

Accepté

## Contexte

Nos presets étendent `w5s/renovate-config`, un dépôt tiers que nous ne maîtrisons pas. Ce qu'il change est lu depuis sa branche par Renovate, et s'applique chez nous sans revue, sans test et sans PR.

Trois points d'appui :

| Preset Captive | Preset w5s étendu | Ce qu'il apporte |
|---|---|---|
| `base.json` | `w5s:_base` | `minimumReleaseAge: "2 days"` global (via `preset/security`), `prCreation: "immediate"`, `docker:pinDigests`, `helpers:pinGitHubActionDigests`, schedule, labels, commit, `lockFileMaintenance`, `separateMajorMinor`, `ignoreUnstable`, `forkProcessing`, alertes de vulnérabilité |
| `preset/automergeBase.json` | `preset/automergeRecommended` | automerge CI, npm, devDependencies, gestionnaires de paquets, `@types` minor, gestionnaires de versions, lock file maintenance, sécurité |
| `preset/groupRecommended.json` | `preset/groupRecommended` | `group:monorepos`, `group:recommended` et des groupes (React, React Native, Vite, Jest, OpenTelemetry...) |

Incident du 2026-11-09 : sur captive-platform, 5 PR de digests d'images tierces bloquées sur `renovate/stability-days`, dont une ouverte depuis 4 jours pour un délai de 2. Trois réglages hérités de `w5s:_base` se combinaient : le délai global de 2 jours s'applique aussi aux digests, qui n'ont pas de date de publication ; `docker:pinDigests` en crée ; `prCreation: "immediate"` ouvre la PR avant que le délai soit tenu. Aucun de ces réglages n'était visible dans notre dépôt, ni couvert par nos tests.

## Décision

Tout ce qui retire une dépendance à w5s est une bonne chose à faire. Pas de chantier dédié imposé : chaque changement qui touche un réglage hérité de w5s le reprend chez nous plutôt que de le contourner.

En pratique :

- un réglage dont nous avons besoin est écrit dans nos presets, explicitement, avec un test ;
- un preset w5s se remplace par les presets natifs de Renovate qu'il étend (`group:monorepos`, `docker:pinDigests`...) plus nos propres règles ;
- aucune nouvelle référence à `w5s` n'est ajoutée.

Ordre suggéré, du plus risqué au moins risqué : `w5s:_base` (porte le délai de release et la création des PR), puis `automergeRecommended` (décide de ce qui merge sans revue), puis `groupRecommended`.

## Conséquences

### Points positifs

- Un changement de comportement de Renovate passe par une PR de ce dépôt et ses tests.
- La configuration effective se lit dans notre dépôt, sans remonter une chaîne d'`extends` externe.

### Points de vigilance

- Reprendre un preset w5s change le comportement de tous les dépôts : copier son contenu tel quel d'abord, puis le faire évoluer dans un second temps.
- Nous perdons les améliorations que w5s apporterait : à nous de suivre les presets natifs de Renovate.
