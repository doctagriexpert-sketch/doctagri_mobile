# Livraison et exploitation

## Définition de terminé

Une tâche est terminée quand son comportement attendu est implémenté, les contrôles
pertinents sont exécutés et la documentation affectée est cohérente. Si une étape
est bloquée, nommer le blocage et ne pas annoncer la fonctionnalité comme déployée.

Pour une livraison terrain, ajouter : version identifiable, APK signé avec la
clé historique, installation par mise à jour vérifiée, scénario hors ligne puis
reconnexion, contrats serveur déployés et procédure de retour connue.

## Release

- Ne pas augmenter une version ni créer un tag à l'occasion d'une simple analyse.
  Pour une release demandée, incrémenter le build, écrire les changements et
  consigner le commit, les migrations, modèles et vérifications associés.
- Produire les artefacts avec la configuration cible. Les valeurs Flutter sont
  des `dart-define` ; une variable de shell seule ne les injecte pas.
- Ne pas changer de clé de signature Android pour contourner un problème de build.
  Ne pas retomber silencieusement sur la signature debug pour une release.
- Les migrations de production et les publications sont des opérations distinctes
  du développement. Utiliser l'autorisation déjà donnée, sinon présenter le résultat
  et l'environnement précis avant l'opération externe.
- Les workflows manuels ne deviennent des déploiements automatiques qu'une fois
  les environnements, secrets et critères de validation réellement configurés.

## Exploitation

Documenter les signaux utiles avant d'annoncer un service surveillé : erreurs,
tentatives, latence et état de la file, sans contenu sensible. Un dashboard écrit
dans la documentation n'est pas un dashboard déployé.

Les objectifs de performance deviennent des engagements après une mesure datée,
sur appareil/corpus identifiés. Toute dette bloquante de release a un critère de
résolution, pas seulement une date souhaitée.
