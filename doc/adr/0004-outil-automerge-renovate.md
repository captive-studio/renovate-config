# 4. Outil d'automerge des PR Renovate en attente

Date : 2026-07-08

## Statut

Accepté

## Contexte

Chaque semaine, un ticket Jira (projet `FAC`, résumé `Maintenance Renovate du JJ/MM/AA`) liste les repos à traiter pour la routine de maintenance Renovate (exemple : [FAC-2514](https://captive-team.atlassian.net/browse/FAC-2514)). L'objectif de cette routine, décrit dans le ticket, est de traiter l'ensemble des PR Renovate ouvertes en 20 minutes maximum.

En pratique, une part importante de ces PR sont déjà prêtes à être fusionnées : Renovate les a marquées `automerge: enabled` dans sa configuration et tous les checks CI sont au vert, mais Renovate ne les a pas encore fusionnées lui-même (son prochain passage planifié n'est pas encore arrivé). Exemple observé : [groove-application#414](https://github.com/captive-studio/groove-application/pull/414), où `mergeStateStatus` est `CLEAN`, tous les checks sont `SUCCESS`, et le corps de la PR contient `🚦 **Automerge**: Enabled.` - mais `autoMergeRequest` (l'automerge natif GitHub) est `null` : personne ne l'a fusionnée.

Fusionner ces PR à la main, repo par repo, est le principal poste de temps de la routine hebdomadaire.

## Décision

On construit un outil CLI autonome, dans ce repo (`renovate-config`), qui automatise la fusion de ces PR "déjà prêtes".

### Stack technique

- **Ruby**, en autonome dans ce repo (`Gemfile`/`bin/`/`lib/` propres), indépendant de `captive-ruby` bien qu'il en reprenne les conventions :
  - `thor` pour le parsing de commandes, avec sous-commandes si pertinent
  - `tty-prompt`, `tty-spinner`, `pastel` pour l'UI terminal
  - RSpec avec 100% de couverture
  - rubocop + rubycritic, score minimum 96
- **GitHub** : via le `gh` CLI déjà authentifié sur le poste (pas de token dédié à gérer).
- **Jira** : via l'API REST Jira, en `Net::HTTP` (stdlib, pas de gem HTTP supplémentaire), avec un token API Jira dédié fourni par variable d'environnement.

### Détection du ticket Jira

- Par défaut : recherche JQL du dernier ticket du projet `FAC` dont le résumé matche "Maintenance Renovate", trié par date de création décroissante.
- Argument optionnel pour forcer une clé de ticket précise (rejouer un ticket passé, tester).

### Extraction de la liste des repos

- Parsing de la description du ticket : extraction de toutes les URLs `github.com/{org}/{repo}` présentes (sous forme de liens Markdown), quelle que soit la casse ou l'org (le ticket peut inclure un repo hors `captive-studio`, ex. `Guitguitou/as-monaco-beachvolley`). Aucune règle de filtrage par org dans le code : le ticket Jira, maintenu à la main chaque semaine, est la seule source de vérité sur les repos à traiter.

### Sélection des PR à traiter

Pour chaque repo, on liste les PR ouvertes dont l'auteur est le bot `app/renovate` (vérifié stable sur plusieurs repos de la liste).

Pour chaque PR, dans cet ordre :

1. **Automerge désactivé ?** Le corps de la PR ne contient pas `🚦 **Automerge**: Enabled.` (ex : `Disabled by config`) → on ignore la PR, elle reste en revue manuelle.
2. **Branche pas à jour ?** `mergeStateStatus == BEHIND` → on coche la case `- [ ] <!-- rebase-check -->If you want to rebase/retry this PR, check this box` dans le corps de la PR (édition du corps). Ça déclenche un rebase par Renovate à son prochain passage. On n'attend pas ce rebase : on passe à la PR suivante.
3. **Checks pas tous verts ?** On exige que **tous** les checks visibles dans `statusCheckRollup` soient `SUCCESS`, `SKIPPED` ou `NEUTRAL` - peu importe qu'ils soient marqués "requis" ou non par la protection de branche du repo (donc plus strict que le simple `mergeStateStatus == CLEAN` de GitHub, qui ignore les checks non-requis). Si un check est `FAILURE`, `CANCELLED`, `TIMED_OUT`, `ACTION_REQUIRED`, ou encore `PENDING`/`IN_PROGRESS` → on ignore la PR.
4. **Autre obstacle** (conflit, draft, blocage de protection de branche) → on ignore la PR, avec la raison rapportée.
5. **Sinon** → on fusionne la PR avec `gh pr merge`, en essayant les stratégies dans l'ordre `rebase > squash > merge` (auto-détection de la première autorisée par le repo). L'ordre reflète la convention Captive de fusionner par rebase par défaut.

### Exécution et rapport

- Exécution directe, sans mode `--dry-run` : l'outil agit dès son lancement (le but est de gagner du temps, pas d'ajouter une étape de validation).
- Résumé final affiché en terminal, dans le style de `bin/autorise-dependance` (codes couleur ✓/✗/→) : une ligne par PR traitée, groupée par repo, avec l'action prise (mergée / rebase demandé / ignorée + raison), et un total en bas.

### Hors scope

Le ticket Jira décrit 3 étapes ; cet outil ne couvre que la première :

1. ✅ Traiter les PR Renovate ouvertes → couvert par cet outil.
2. ❌ Améliorer la config Renovate (ex : nouvel automerge, groupement de gems) → reste manuel, via `bin/autorise-dependance` ou édition directe des presets.
3. ❌ Commenter l'amélioration sur le ticket Jira → reste manuel.

## Conséquences

### Points positifs

- La majorité du temps de la routine hebdomadaire (fusionner les PR déjà prêtes) devient une commande unique.
- Zéro nouveau token/credential à gérer côté GitHub (réutilise `gh` déjà authentifié).
- Détection automatique du ticket de la semaine : zéro copier-coller.
- Le comportement sur les PR non prêtes (BEHIND, checks rouges, automerge désactivé) est explicite et ne fusionne jamais quelque chose qui ne devrait pas l'être.

### Points de vigilance

- Un token API Jira dédié doit être créé et stocké (variable d'environnement) - à faire une fois, à renouveler si Atlassian le révoque.
- Le format du corps des PR Renovate (`🚦 **Automerge**: Enabled.`, checkbox `rebase-check`) est un détail d'implémentation de Renovate/Mend : si Renovate change ce format un jour, le parsing cassera silencieusement (à surveiller via le rapport : si plus aucune PR n'est jamais reconnue comme automergeable, c'est le premier suspect).
- Le repo `Guitguitou/as-monaco-beachvolley` étant hors org captive-studio, il faut s'assurer que le token `gh` utilisé a bien les droits d'écriture dessus (sinon la fusion échouera pour ce repo spécifiquement, ce qui sera visible dans le rapport final sans bloquer les autres repos).
- Pas de dry-run : toute évolution du comportement de sélection/fusion doit être testée unitairement (RSpec) avant d'être exécutée en conditions réelles, puisqu'il n'y a pas de garde-fou d'exécution.
