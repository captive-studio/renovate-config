# 🤖 automerge-renovate

> CLI Ruby qui automatise la routine hebdomadaire de maintenance Renovate : trouve le ticket Jira de la semaine, fusionne les PR Renovate déjà prêtes, relance les checks CI rouges, et te dit exactement quoi regarder toi-même.

Sous-projet Ruby autonome (son propre `Gemfile`, `lib/`, `spec/`) à l'intérieur du repo [`renovate-config`](../README.md). Ne dépend d'aucune autre partie du repo.

---

## 🗺️ La routine hebdomadaire, en 3 étapes

Chaque semaine, un ticket Jira (projet `FAC`, résumé `Maintenance Renovate du JJ/MM/AA`) liste les repos à traiter. Le ticket décrit 3 étapes — cet outil n'en couvre qu'une :

| # | Étape | Qui s'en occupe |
|---|-------|------------------|
| 1 | Fusionner les PR Renovate déjà prêtes, relancer les checks rouges | **Cet outil**, automatiquement |
| 2 | Améliorer la config Renovate (nouvel automerge, groupement de gems...) | Toi, à la main — voir [`bin/autorise-dependance`](../bin/autorise-dependance) et le [README racine](../README.md) |
| 3 | Commenter l'amélioration faite sur le ticket Jira | Toi, à la main |

Le [standard Notion sur les PR Renovate](https://www.notion.so/captive/Maintenance-Routine-de-mises-jour-de-d-pendances-avec-Renovate-1f04dbb3678e4591a37e0a75e4615a8e) décrit la routine complète (pas seulement l'étape 1).

Ce que l'outil te laisse dans les mains à la fin de l'étape 1, ce sont deux listes dans le rapport :

- **⚠ Décisions à prendre** : checks verts mais automerge désactivé → active l'automerge, merge ponctuellement, ou ignore, au cas par cas.
- **⚠ PR à investiguer** : checks rouges → comprends pourquoi (un rerun a été tenté automatiquement si possible, voir plus bas).

---

## 🚀 Quick start

### Prérequis

- [`asdf`](https://asdf-vm.com/) avec Ruby 4.0.5 installé (`asdf install ruby 4.0.5` depuis ce dossier — la version est fixée par [`.tool-versions`](.tool-versions))
- [`gh`](https://cli.github.com/) authentifié (`gh auth status`), avec accès en écriture sur tous les repos listés dans le ticket
- Un [token API Jira](https://id.atlassian.com/manage-profile/security/api-tokens)

### Installation

```sh
cd automerge-renovate
bundle install
cp .env.example .env
# édite .env : renseigne JIRA_EMAIL et JIRA_API_TOKEN
```

### Utilisation

Depuis la racine du repo, ou depuis `automerge-renovate/` :

```sh
# Trouve automatiquement le dernier ticket "Maintenance Renovate" et traite tous ses repos
bin/automerge-renovate automerge

# Rejoue un ticket précis (test, ou ticket passé)
bin/automerge-renovate automerge FAC-2514
```

L'outil affiche sa progression en direct (recherche du ticket → repos trouvés → chaque PR traitée), puis un récapitulatif et les deux listes ci-dessus. Aucun mode `--dry-run` : il agit dès son lancement.

---

## ⚙️ Variables d'environnement

| Variable | Obligatoire | Défaut | Description |
|---|---|---|---|
| `JIRA_EMAIL` | oui | — | Email du compte Atlassian associé au token |
| `JIRA_API_TOKEN` | oui | — | [Token API Jira](https://id.atlassian.com/manage-profile/security/api-tokens) |
| `JIRA_SITE` | non | `captive-team.atlassian.net` | Site Atlassian |

Chargées depuis `.env` (gitignoré) via la gem `dotenv`, voir [`bin/automerge-renovate`](bin/automerge-renovate).

---

## 🧱 Architecture

L'outil suit un pipeline simple : **Jira → repos → PR → décision → action → rapport**. Chaque classe a une seule responsabilité (SRP), les dépendances externes (`gh`, HTTP Jira) sont injectées pour rester testables sans réseau.

| Classe | Responsabilité |
|---|---|
| `Cli` | Commande Thor, câble tout le reste |
| `AutomergeCommand` | Orchestre un run complet (ticket → repos → fusion → rapport) |
| `JiraClient` / `JiraHttp` | Dernier ticket par JQL, ou ticket précis par clé |
| `AdfToText` | Convertit la description Jira (format ADF) en texte exploitable |
| `RepoUrlExtractor` | Extrait les repos `github.com/org/repo` de la description du ticket |
| `GhCli` | Wrapper autour du CLI `gh` (liste les PR, merge, édite le corps, relance des jobs) |
| `PrDecision` | Décide de l'action pour une PR : merge, rebase demandé, ou skip + raison |
| `AutomergeStatus` | Automerge activé ou non, d'après le corps de la PR |
| `ChecksEvaluator` | Tous les checks verts ? Lesquels sont rouges ? |
| `MergeStrategyPicker` | Choisit rebase > squash > merge selon ce que le repo autorise |
| `RebaseCheckbox` | Coche la case "rebase/retry" dans le corps de la PR |
| `DecisionExecutor` | Applique la décision via `gh` (merge/rebase), convertit un échec `gh` en skip |
| `FailedChecksRerunner` / `GithubActionsRunIds` | Relance les jobs GitHub Actions en échec sur les PR à investiguer |
| `Runner` | Orchestre repos → PR → décision → exécution, notifie la progression en direct |
| `Report` / `ActionTally` | Rapport final coloré, groupé par repo, avec total |
| `FlaggedPrList` | Liste générique de PR portant un flag donné (`needs_decision`, `needs_investigation`), avec lien |
| `ProgressPrinter` | Affiche toute la progression en direct (recherche, repos, PR, rapport final) |

---

## 🧪 Tests & qualité

Standards non négociables sur ce projet (voir les conventions Ruby internes) :

```sh
bundle exec rspec                                 # 100% de couverture attendue
bundle exec rubocop                               # aucune offense
bundle exec rubycritic lib --no-browser -f console  # score minimum 96
```

TDD strict (rouge → vert → refactor, un test à la fois). **Si le score RubyCritic tombe sous 96** : ne pas tenter de le remonter à la main (commentaires de classe, micro-refactors au hasard) — le score dépend uniquement du Flog (complexité) et du nombre de fichiers, pas des smells Reek. Le levier qui marche : extraire du code dans un nouveau fichier (augmente le dénominateur). Utiliser le skill `/rubycritic-improve` si disponible.

---

## ⚠️ Pièges connus

- **L'API Jira `GET /rest/api/3/search` est dépréciée** (message d'erreur explicite d'Atlassian). `JiraClient` utilise `POST /rest/api/3/search/jql`. Si Atlassian déprécie ce nouvel endpoint à son tour, le message d'erreur JSON du body sera explicite — ce n'est pas un problème d'auth.
- **La description d'un ticket Jira est au format ADF** (JSON structuré), pas du texte brut — `AdfToText` la convertit. Si `RepoUrlExtractor` ne trouve plus aucun repo alors que le ticket en liste, vérifier que la conversion ADF fonctionne toujours (le format ADF n'a pas de garantie de stabilité côté Atlassian).
- **`gh run rerun` est asynchrone** : le rapport peut afficher "(rerun déclenché)" sans que le check ne redevienne vert avant la fin du run - c'est attendu, le résultat sera visible au passage suivant de l'outil.
- **`FailedChecksRerunner` ne peut rejouer que les `CheckRun`** (jobs GitHub Actions). Un check `StatusContext` (ex: `renovate/stability-days`) rouge n'aura jamais de mention "(rerun déclenché)" - c'est normal, il n'y a rien à rejouer.

Détail des décisions et de leur raisonnement : [`doc/adr/0004-outil-automerge-renovate.md`](../doc/adr/0004-outil-automerge-renovate.md) et [`doc/adr/0005-rerun-checks-rouges.md`](../doc/adr/0005-rerun-checks-rouges.md).

---

## 📚 Pour aller plus loin

- [ADR 0004 — Outil d'automerge des PR Renovate en attente](../doc/adr/0004-outil-automerge-renovate.md)
- [ADR 0005 — Redéclenchement automatique des checks CI rouges](../doc/adr/0005-rerun-checks-rouges.md)
- [Standard Notion — Routine de mises à jour de dépendances avec Renovate](https://www.notion.so/captive/Maintenance-Routine-de-mises-jour-de-d-pendances-avec-Renovate-1f04dbb3678e4591a37e0a75e4615a8e)
- [Ticket Jira du projet FAC](https://captive-team.atlassian.net/browse/FAC-2514) (exemple)
