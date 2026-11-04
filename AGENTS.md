## Agent skills

### Issue tracker

Les tickets vivent dans les GitHub Issues de captive-studio/renovate-config. Voir `docs/agents/issue-tracker.md`.

### Triage labels

Les cinq labels par défaut (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). Voir `docs/agents/triage-labels.md`.

### Domain docs

Single-context : `GLOSSARY.md` à la racine, ADR dans `doc/adr/`. Voir `docs/agents/domain.md`.

## Mode autonome

Quand un agent implémente une spec de ce dépôt (skill `/implement-spec` ou équivalent), il peut, pour cette spec et ses tickets :

- `git add` et `git commit` (Gitmoji, français) ;
- rebaser sur la branche d'intégration, seule méthode de merge du dépôt ;
- créer et pousser des branches `feature/*` et `ticket/*` (jamais `main`, jamais de force-push sur `main`) ;
- ouvrir la PR en brouillon de la branche d'intégration vers `main`, puis la marquer prête pour relecture ;
- commenter et fermer les tickets de la spec une fois leur travail intégré.

Restent interdits : merger sur `main`, bumper une version, publier une release.
