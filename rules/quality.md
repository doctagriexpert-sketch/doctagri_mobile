# Qualité vérifiable

## Contrôles

| Changement | Vérifications minimales pertinentes |
|---|---|
| Documentation, règles, skills, hooks | `python scripts/quality.py repository` |
| Flutter | `python scripts/quality.py flutter` et tests ciblés pendant le travail |
| Dashboard | `python scripts/quality.py dashboard` |
| Pipeline Python | `python scripts/quality.py python` ; expérience ML adaptée au changement |
| Android natif ou plugin | Compilation debug et scénario sur appareil si le comportement dépend d'Android |
| SQL, RPC, RLS | Migration sur base de test + tests positifs/négatifs par rôle + reprises |
| Modèle ou prétraitement | Parité Python/Flutter + corpus étiqueté + métriques par culture |

`python scripts/quality.py all` exécute les contrôles locaux ci-dessus qui ne
nécessitent ni serveur ni appareil. Il ne valide pas automatiquement SQL, iOS,
les modèles sur terrain ou une release signée.

## Tests utiles

Un correctif de logique ou de contrat comporte un test de régression qui échoue
avant correction. Tester le résultat observé, pas une copie de l'algorithme dans
le test. Pour synchronisation : perte réseau, rejeu et redémarrage. Pour droits :
accès permis et accès refusé. Pour une retouche de texte, ne pas créer de test artificiel.

Ne pas désactiver une règle, ignorer un test ou ajouter `continue-on-error` pour
masquer une erreur. Une exception ponctuelle doit expliquer son périmètre, son
risque et son critère de suppression dans la dette technique. Les contrôles
complets restent bloquants même lorsque la dette est antérieure au changement.

## Revue

Le diff doit être compréhensible sans la conversation de l'auteur. Une PR décrit
le problème, le comportement final, la preuve de validation et les risques
résiduels. L'auteur examine aussi le code généré par un assistant.

Hooks : validation rapide du contenu préparé dans l'index, sans réécriture ni
`git add` automatique. CI : contrôle de tout le dépôt versionné et suites complètes.
Le formateur ne modifie aucun fichier pendant un contrôle. Les fichiers générés
ne sont pas reformattés manuellement.
