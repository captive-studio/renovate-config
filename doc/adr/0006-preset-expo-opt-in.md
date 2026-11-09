# 6. Les règles propres à Expo sortent des presets communs

Date : 2026-11-09

## Statut

Accepté

## Contexte

`preset/groupExpo` est étendu par `preset/groupRecommended`, donc par `recommended`, `application` et `library` : toutes ses règles s'appliquent à tous les dépôts, Expo ou non.

Il contient des règles `enabled: false` pour les **dépendances verrouillées par Expo** (`@babel/core`, `react-native`, `@react-native/**`...). Sur un dépôt sans Expo, elles désactivent ces dépendances sans aucune raison. Incident : sur Notion2Markdown (Rails + webpack), Renovate a groupé le monorepo Babel en v8 sans `@babel/core`, resté en v7. `@babel/plugin-transform-runtime@8` exige `@babel/core@^8`, donc `npm install` échoue en `ERESOLVE` et la PR ne peut pas passer. Relancer Renovate n'y change rien : `@babel/core` n'est même pas détecté.

Renovate ne sait pas conditionner une règle à la présence d'Expo dans le dépôt.

## Décision

Les règles qui n'ont de sens que dans un dépôt Expo vont dans un preset optionnel, `preset/expo`, que chaque dépôt Expo ajoute à ses `extends` en plus de `:application` ou `:library` :

- les dépendances verrouillées par Expo (`enabled: false`), dont `@babel/core` ;
- `@react-native/**` (`enabled: false`) ;
- le délai de 45 jours sur les majeures Expo ;
- la stratégie `rangeStrategy: bump` sur `@react-navigation/*`, attendue par expo-doctor.

Le regroupement « Expo & React Native core » reste dans `groupExpo` : il ne bloque aucune dépendance.

Nous avons écarté un preset racine `:expoApplication` qui remplacerait `:application`, parce qu'il ne couvre pas les libraries Expo (ex. `alveole-js`).

### Migration en trois temps

Les presets sont lus depuis `main` : retirer les règles avant que les dépôts Expo aient adopté `preset/expo` les laisserait sans verrous, et Renovate pourrait alors monter `react-native` ou `@babel/core` hors SDK.

1. Ajout de `preset/expo`, sans rien retirer de `groupExpo` (les règles sont en double pendant la transition).
2. Chaque dépôt Expo ajoute `github>captive-studio/renovate-config//preset/expo` à ses `extends`.
3. Retrait des règles de `groupExpo` et de `recommended`, avec un test qui vérifie que `application` et `library` ne désactivent aucun paquet `@babel/*`.

## Conséquences

### Points positifs

- Les dépôts sans Expo reçoivent à nouveau les mises à jour de `@babel/core` et des autres dépendances verrouillées par Expo.
- Les presets communs ne portent plus de règle propre à un écosystème.

### Points de vigilance

- Un nouveau dépôt Expo qui oublie `preset/expo` n'a aucun verrou : Renovate peut lui proposer des montées incompatibles avec son SDK. Le README doit le dire.
- La même question se posera pour d'autres écosystèmes (Capacitor, Ionic, Tamagui) dont les règles sont aujourd'hui dans `groupRecommended`.
