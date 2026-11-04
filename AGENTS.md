## Agent skills

### Issue tracker

Les tickets vivent dans les GitHub Issues de captive-studio/renovate-config. Voir `docs/agents/issue-tracker.md`.

### Triage labels

Les cinq labels par défaut (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). Voir `docs/agents/triage-labels.md`.

### Domain docs

Single-context : `GLOSSARY.md` à la racine, ADR dans `doc/adr/`. Voir `docs/agents/domain.md`.

## Mode autonome

Pour le chantier de la spec #3944 (tickets #3945 à #3950), sur la branche d'intégration `feature/timestamp-required` et les branches de ticket qui en partent, les agents peuvent :

- `git add` et `git commit` (Gitmoji, français) ;
- rebaser sur la branche d'intégration, seule méthode de merge du dépôt ;
- `git push` de ces branches (jamais sur `main`, jamais de force-push sur `main`) ;
- ouvrir la PR en brouillon de la branche d'intégration vers `main`, puis la marquer prête pour relecture ;
- commenter et fermer les tickets #3945 à #3950 une fois leur travail intégré.

Restent interdits : merger sur `main`, bumper une version, publier une release.
