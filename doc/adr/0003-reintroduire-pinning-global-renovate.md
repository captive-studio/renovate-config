# 3. Réintroduire le pinning global des dépendances avec Renovate

Date : 2026-03-31

## Statut

Accepté

## Contexte

Cet ADR complète et remplace partiellement l'ADR [0002 - Ne pas pinner les dépendances pour les applications](0002-do-not-pin-dependencies-for-applications.md).

Dans l'ADR 0002, nous avions décidé de ne pas pinner systématiquement les dépendances des applications, en considérant qu'il suffisait :

- d'éviter les dépendances sans contrainte (ex. `gem "my-gem"` sans version), et
- d'accepter soit des versions exactes, soit des ranges (ex. `~> 1.0.0`).

Depuis, deux constats ont changé notre perception :

1. **Expo est très rigide sur les versions, et les lockfile maintenances de Renovate ont introduit des mises à jour non désirées.**  
   - Des PR de type *lockfile maintenance* ont modifié des versions dans le `lockfile` sans changement explicite de contrainte dans les manifests (`package.json`, etc.).  
   - Avec Expo, cela peut facilement casser le projet ou rendre la mise à jour très pénible, car le SDK s'attend à un ensemble très précis de versions.

2. **Renovate passe déjà sur l'ensemble des dépendances, même non pinnées.**  
   - En pratique, nous ne voyons pas de gain significatif à laisser des ranges dans nos manifests.  
   - Avoir des contraintes explicites et exactement alignées sur ce que Renovate propose dans ses PR rend les mises à jour plus prévisibles et plus lisibles.

## Décision

Nous décidons de **réintroduire un pinning global des dépendances dans la configuration partagée Renovate**, en nous appuyant sur le preset intégré `:pinAllExceptPeerDependencies`.

Concrètement :

- Le preset `recommended` étend désormais `:pinAllExceptPeerDependencies`.
- Les presets publics `application` et `library` continuent d'étendre `recommended`.

Cela signifie que, pour les projets qui étendent :

- `github>captive-studio/renovate-config:application`, ou
- `github>captive-studio/renovate-config:library`,

Renovate va normaliser les contraintes de version supportées en **versions exactes** dans les PR.

Exemple pour npm :

```json
// package.json (avant)
{
  "dependencies": {
    "some-package": "^1.2.3"
  }
}
```

devient, dans une PR Renovate :

```json
// package.json (après)
{
  "dependencies": {
    "some-package": "1.2.3"
  }
}
```

Exemple pour Ruby/Bundler :

```ruby
# Gemfile (avant)
gem "my-gem", "~> 1.0.0"
```

devient :

```ruby
# Gemfile (après)
gem "my-gem", "1.0.0"
```

Le `Gemfile.lock` reste la source de vérité pour la résolution exacte, mais le fait de pinner dans le `Gemfile` permet d'aligner très clairement l'intention avec l'état réel maintenu par Renovate.

Les `peerDependencies` restent non pinnées par conception (`:pinAllExceptPeerDependencies`).

## Conséquences

### Points positifs

- **Comportement plus prévisible avec Expo et autres stacks rigides** :  
  Les updates sont toujours accompagnées d'un changement explicite de contrainte dans le manifest, ce qui évite les surprises issues des seules lockfile maintenances.

- **Lisibilité accrue des PR Renovate** :  
  Les PR montrent clairement le passage d'une version exacte à une autre, plutôt que des évolutions implicites à l'intérieur d'un range.

- **Alignement entre intention et réalité** :  
  Les fichiers de manifeste (Gemfile, package.json, etc.) reflètent la version réellement visée, ce qui simplifie le debug et les audits de dépendances.

### Points négatifs / risques

- **Moins de flexibilité implicite** :  
  En pinner systématiquement, on perd la possibilité de laisser la résolution “flotter” à l'intérieur d'un range sans intervention de Renovate.

- **Plus de “churn” apparent sur les manifests** :  
  Les fichiers comme `package.json` et `Gemfile` changent plus souvent, puisqu'ils reflètent directement les mises à jour de version proposées par Renovate.

## Relation avec l’ADR 0002

- L’ADR 0002 reste valable en tant que **photo historique** de la décision initiale de ne pas pinner systématiquement les dépendances d’applications.
- Le présent ADR (0003) **amende et, dans les faits, remplace** cette décision pour les projets qui utilisent les presets partagés `application` et `library` basés sur `recommended`.

