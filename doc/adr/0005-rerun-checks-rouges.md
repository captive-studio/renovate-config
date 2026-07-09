# 5. Redéclenchement automatique des checks CI rouges

Date : 2026-07-08

## Statut

Accepté

## Contexte

Depuis l'ADR [0004](0004-outil-automerge-renovate.md), le rapport de l'outil `automerge-renovate` distingue les PR "à investiguer" : automerge activé mais au moins un check non vert. Certaines de ces PR sont simplement victimes d'un test flaky ou d'un run CI ponctuellement instable - un simple rerun suffirait à les débloquer, sans intervention humaine.

## Décision

Quand une PR est classée "à investiguer", l'outil tente de redéclencher automatiquement les jobs GitHub Actions en échec, via `gh run rerun <run-id> --failed`.

### Ce qui est rejouable, ce qui ne l'est pas

Les checks d'une PR (`statusCheckRollup`) sont de deux natures :

- **`CheckRun`** : un job GitHub Actions. Son `detailsUrl` contient l'identifiant du run (`.../actions/runs/<run-id>/job/<job-id>`), rejouable.
- **`StatusContext`** : un statut externe (ex : `renovate/stability-days`). Aucun run à rejouer - ignoré silencieusement par le mécanisme de rerun (il reste dans la liste des raisons possibles d'un check rouge, mais rien à déclencher).

Pour chaque PR à investiguer, l'outil extrait les `run-id` distincts des `CheckRun` non verts, et appelle `gh run rerun <run-id> --repo <repo> --failed` une fois par run distinct (une PR peut avoir plusieurs workflows CI, donc plusieurs runs).

### Asynchrone, sans condition

- **Asynchrone** : l'outil déclenche le rerun et continue immédiatement, sans attendre sa fin. Attendre un rerun GitHub Actions (plusieurs minutes) pour chaque PR à investiguer irait à l'encontre de l'objectif "20 minutes max" de la routine hebdomadaire. Le résultat du rerun (vert ou toujours rouge) sera visible au passage suivant de l'outil, pas dans le rapport courant.
- **Sans condition, à chaque run** : pas de garde-fou "déjà retenté récemment". La cadence hebdomadaire de l'outil rend le risque de boucle rapprochée nul en pratique ; ajouter un état persistant pour l'éviter coûterait plus cher que le bénéfice.

### Visibilité dans le rapport

La ligne de la section "PR à investiguer" indique si un rerun a été déclenché :

```
⚠ PR à investiguer (checks rouges) :
  - https://github.com/captive-studio/monocle/pull/981 (rerun déclenché)
  - https://github.com/captive-studio/groove-application/pull/393
```

L'absence de mention signifie qu'aucun `CheckRun` rejouable n'a été trouvé (uniquement des `StatusContext` externes, ou l'appel `gh run rerun` a échoué) - un signal qu'une investigation manuelle est nécessaire sans attendre un rerun qui n'aura pas lieu.

### Résilience

Un échec de `gh run rerun` (run trop ancien, workflow désactivé, droits insuffisants) est traité comme les autres échecs `gh` de l'outil : capturé, la PR reste "à investiguer" sans mention de rerun, le run global continue sur les autres PR.

## Conséquences

### Points positifs

- Récupère automatiquement les PR bloquées par un test flaky, sans action manuelle.
- Le rapport reste honnête : la mention "(rerun déclenché)" évite de faire croire qu'un rerun a eu lieu quand ce n'était pas possible.

### Points de vigilance

- Consomme des minutes CI à chaque run de l'outil pour les PR dont les checks sont rouges de façon stable (vraie régression). Le coût reste faible comparé à la fréquence hebdomadaire de l'outil.
- Si une PR reste rouge semaine après semaine, elle sera rejouée à chaque passage sans qu'aucune mémoire ne soit gardée : c'est un choix assumé (cf. ci-dessus), à revoir si le volume de PR chroniquement rouges devient significatif.
