# 8. Quand et comment l'outil d'automerge rebase les PR Renovate

Date : 2026-11-17

## Statut

Accepté. Remplace les étapes 1 à 3 de la sélection des PR de l'ADR [0004](0004-outil-automerge-renovate.md).

## Contexte

L'ADR 0004 cochait la case de rebase Renovate pour toute PR en retard, puis l'outil a appris à attendre ce rebase et la CI (15 min max) pour fusionner toutes les PR d'un repo dans le même run. En usage réel :

- Après chaque fusion, la PR suivante du repo passe en retard. Renovate ne traite la case cochée qu'à son prochain passage, souvent au-delà des 15 min, alors que le bouton GitHub « Rebase and merge » agit tout de suite.
- Une PR en conflit bloquait le run 15 min pour un rebase que seul Renovate peut faire, sans délai garanti.
- Une PR à automerge désactivé (une **Majeure à valider**) était rebasée à chaque run, ce qui relançait sa CI après chaque fusion, sans décision humaine derrière.
- Un check encore en file d'attente était pris pour un check rouge : PR « à investiguer » et attente après rebase interrompue aussitôt.

## Décision

L'outil ne rebase que lorsque GitHub refuse de fusionner la PR telle quelle, et n'attend que les rebases qu'il fait lui-même.

| État de la PR | Action |
|---|---|
| Automerge désactivé | aucun rebase ; signalée dans les **Décisions à prendre**, checks verts ou rouges |
| `UNKNOWN` (état de fusion pas encore calculé) | relue jusqu'à 5 fois à 2 s d'intervalle ; toujours `UNKNOWN` : ignorée, reprise au run suivant |
| Verte, en retard, mais `mergeStateStatus` `CLEAN` (la base n'exige pas d'être à jour) | fusion directe, sans rebase ni nouvelle CI |
| `BEHIND` (la protection de branche exige une branche à jour) | rebase immédiat par GitHub (`gh pr update-branch --rebase`), attente de la CI, puis fusion dans le même run |
| `DIRTY` (conflit, souvent de lockfile) | case de rebase Renovate cochée, **sans attente** : la PR sera reprise au run suivant |
| Checks en cours (file d'attente, exécution, statut `PENDING`) | ignorée avec « checks en cours », sans rerun |
| `renovate/stability-days` en attente | ignorée avec « version trop récente (minimumReleaseAge) » |
| `renovate/artifacts` en échec (Renovate n'a pas su mettre à jour le lockfile) | à investiguer, **sans rerun** : relancer la CI n'y changerait rien |
| Au moins un check rouge, même en retard | à investiguer et rerun (ADR [0005](0005-rerun-checks-rouges.md)), sans rebase ; prioritaire sur un check en cours |
| Verte mais bloquée par GitHub pour une autre raison (`BLOCKED`…) | ignorée avec « fusion bloquée par GitHub », sans rebase |
| Merge refusé pour conflit alors que GitHub la disait `CLEAN` | case de rebase Renovate cochée, comme pour `DIRTY` |

L'outil liste les PR d'un repo une fois, au début. Après une fusion dans ce repo, chaque PR suivante est relue avant d'être décidée : son état a changé.

`--no-wait` désactive toute attente : un run rapide qui laisse les PR rebasées « rebase demandé » jusqu'au run suivant.

## Options écartées

- **Toujours déléguer le rebase à Renovate** (case cochée) : fidèle à Renovate, mais l'attente dépend de son planning et dépasse souvent le délai du run.
- **Rebaser les PR à automerge désactivé pour les garder « décidables »** : la CI fraîche ne sert que le jour où un humain décide ; le reste du temps, elle est relancée en pure perte. On rebase à la main la PR qu'on s'apprête à trancher.

## Conséquences

- Une PR fusionnée sans rebase a vu sa CI tourner sur l'ancienne base : une incompatibilité avec la PR fusionnée juste avant ne se voit qu'après le merge. C'est le même risque que le bouton « Rebase and merge » de GitHub, accepté pour des PR que Renovate automerge déjà.
- Le rebase par GitHub est poussé sous l'identité de la personne qui lance l'outil, pas de Renovate.
- Le retard d'une PR sur sa base n'est plus mesuré (plus d'appel `compare` par PR) : seul l'état de fusion renvoyé par GitHub compte.
- `gh` renvoie une conclusion vide (`""`) pour un check non terminé : elle doit être lue comme absente, sous peine de prendre le check pour rouge.
