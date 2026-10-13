# État du projet — 2 octobre 2026

Ce constat provient de la lecture du dépôt et des vérifications locales décrites
dans les rapports. Il ne certifie pas l'état d'un serveur distant.

| Domaine | État constaté |
|---|---|
| Diagnostic mobile | Parcours Flutter et inférence TFLite implémentés ; précision terrain à mesurer |
| Hors ligne | Historique Hive et file de synchronisation présents |
| Recensement des installations | Worker Android et migration écrits ; déploiement et test physique non confirmés |
| Authentification agriculteur | Méthodes OTP présentes ; parcours UI non raccordé dans les routes examinées |
| Synchronisation des diagnostics | Contrat Flutter différent du schéma SQL versionné ; intégration à corriger |
| Validation experte | Demandes locales ; liaison complète au dashboard non démontrée |
| Dashboard | React : annotations, conflits, fiches, produits et datasets |
| Paiement | Création de commande ; fournisseur et webhook non branchés |
| Packages Melos | Plusieurs squelettes ; code principal encore dans `lib/` |
| Exploitation | Workflows et runbooks présents ; services de monitoring non attestés |

La cible est un produit modulaire et mesurable, pas une multiplication immédiate
des services. La montée en charge sera pilotée par les volumes, les temps de
réponse, les échecs et les contraintes terrain réellement observés.

Les travaux locaux antérieurs à ce cadre (notamment IA et recensement Android)
restent présents. Ce document ne signifie ni qu'ils sont commités ni déployés.

Voir [la dette priorisée](technical-debt.md) avant d'élargir le périmètre produit.
