# Architecture et limites de responsabilité

## Application mobile

- Le parcours photo → diagnostic → historique local reste disponible sans compte
  et sans réseau. La météo, les traductions distantes et la synchronisation
  échouent indépendamment, avec un état explicite pour l'utilisateur.
- Pour le nouveau code métier, `domain/` ne dépend ni des widgets, ni de Hive,
  ni de Supabase. `data/` implémente les interfaces de dépôt ; les pages utilisent
  les providers. Ne pas ajouter de requête SQL ou d'inférence dans un widget.
- Les dépendances sont fournies par l'injection existante. Ne pas multiplier les
  singletons ; isoler progressivement ceux qui existent lorsque la tâche le justifie.
- Les appels réseau ont un délai limite et les reprises sont idempotentes.
  L'état « enregistré localement » est distinct de « reçu par le serveur ».
- Toute évolution d'un format Hive préserve la lecture des données existantes.
  Ne pas réutiliser un identifiant de champ supprimé pour une autre signification.

## Dashboard et backend

- Le dashboard effectif est `doctagri-dashboard/`. Extraire une couche d'accès aux
  données lorsqu'un flux est partagé ou devient difficile à tester, sans déplacer
  tout le code à l'occasion d'une correction locale.
- Les droits sont imposés côté serveur. Masquer un bouton n'est pas une autorisation.
- Préciser quel schéma SQL est ciblé. Les deux historiques actuels exigent une
  décision de convergence avant une migration commune.
- Définir les contrats d'entrée, de sortie, d'erreur et de reprise des nouvelles
  RPC dans `docs/contracts/` lorsqu'ils sont consommés par plusieurs composants.

## Croissance du projet

Conserver un monolithe modulaire tant que les mesures n'imposent pas autre chose.
Extraire un package seulement avec une frontière stable, un consommateur réel et
des tests autonomes. Pour une requête de liste distante : pagination, ordre stable
et index justifié par le filtre ; pas de chargement illimité par défaut.

Une ADR est nécessaire pour un nouveau stockage, un fournisseur externe, une
frontière de module ou un changement de contrat incompatible. Une extraction de
widget ou une correction de bug n'en nécessite pas.
