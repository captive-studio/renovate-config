# Renovate Captive

Configuration Renovate partagée par les dépôts Captive et outillage de suivi des PR de dépendances.

## Language

**Majeure à valider**:
PR de montée de version majeure qu'aucune règle n'automerge : un humain lit le changelog, mesure l'exposition du code, puis merge.
_Avoid_: PR bloquée, PR en attente

**Décision à prendre**:
PR aux checks verts dont l'automerge est désactivé ; aujourd'hui, toujours une **Majeure à valider**. Regroupée par dépendance et version cible (ex. « ransack v5 ×4 »).
_Avoid_: PR à merger, PR orpheline

**Automerge ciblé**:
Règle qui automerge une majeure précise (version source → version cible) une fois validée, pour tous les dépôts.
_Avoid_: whitelist, exception

## Relationships

- Une **Décision à prendre** concerne une dépendance et une version cible, et regroupe une ou plusieurs PR
- Une **Majeure à valider** validée devient un **Automerge ciblé**

## Example dialogue

> **Dev :** « J'ai 4 décisions à prendre ce matin. »
> **Ops :** « Non, une seule : ransack v5 sur 4 dépôts. Une fois validée, on ajoute un automerge ciblé 4 → 5. »
