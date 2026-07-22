# 2. Ne pas pinner les dépendances pour les applications

Date : 2023-04-28

## Statut

Superseded (remplacé) par l’ADR 0003

## Contexte

Cette configuration Renovate est issue d’une version précédente utilisée par Julien Polo dans son ancien poste chez Koober.
La configuration fournie pinait les versions :

`application.json`

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "description": "Default configuration for an application",
  "extends": [
    "github>captive-studio/renovate-config:base",
    ":pinAllExceptPeerDependencies"
  ]
}

```

Par exemple, `:pinAllExceptPeerDependencies` transformera toujours `\"~> 1.0.0\"` en `\"1.0.0\"`.
Cela semble être une bonne pratique pour être explicite, mais ce n’a pas toujours fait consensus (ni entre tous les développeurs, ni au sein de Captive).

## Décision

Il a été décidé que les contraintes sont nécessaires :

```ruby
# PAS OK :
gem "my-gem" # Dangereux et ne peut pas être géré par Renovate

# OK
gem "my-gem", "1.0.0" # Contrainte exacte

# OK
gem "my-gem", "~> 1.0.0" # Contrainte de type range
```

## Conséquences

Ce qui devient plus simple ou plus difficile à faire, ainsi que les risques introduits par ce changement qui devront être pris en compte.

## Suivi : mise à jour de la stratégie de pinning (2026-03-31)

Depuis la rédaction de cet ADR, la configuration partagée a évolué. Le preset `recommended` étend désormais directement le preset intégré de Renovate `:pinAllExceptPeerDependencies`.

Concrètement, cela signifie que les projets qui étendent `github>captive-studio/renovate-config:application` ou `github>captive-studio/renovate-config:library` verront Renovate convertir les ranges de versions supportées en versions exactes dans les PR :

```json
// package.json (npm)
{
  "dependencies": {
    "some-package": "^1.2.3"
  }
}
```

devient :

```json
{
  "dependencies": {
    "some-package": "1.2.3"
  }
}
```

Pour Ruby/Bundler, des ranges comme :

```ruby
gem "my-gem", "~> 1.0.0"
```

sont normalisées en :

```ruby
gem "my-gem", "1.0.0"
```

alors que le `Gemfile.lock` reste la source de vérité pour les versions réellement résolues. Ce suivi réintroduit de fait un pinning global (sauf pour les `peerDependencies`) comme comportement par défaut pour les applications et bibliothèques qui utilisent le preset partagé `recommended`.
