---
name: doctagri-release
description: Préparer une livraison Android terrain de DoctAgri avec configuration serveur, signature historique, preuves de validation et vérification de mise à jour hors ligne.
---

# Préparer une livraison terrain

Lire `rules/delivery.md`, `docs/technical-debt.md` et le guide de la fonctionnalité.

- Relever commit, version/build, modèle embarqué et environnement visé. Ne pas
  produire une release à partir d'un état local mal identifié.
- Exécuter les contrôles adaptés. Une exception de livraison est une décision
  explicite avec son risque, pas la suppression d'un test.
- Vérifier les migrations nécessaires et la compatibilité des APK encore utilisés.
  Ne pas fusionner les historiques SQL pour accélérer une livraison.
- Construire avec une configuration publique cliente explicite et la clé de
  signature Android historique. Ne pas imprimer les secrets ni envoyer le keystore.
- Tester une mise à jour depuis la version distribuée, les données locales,
  le démarrage hors ligne et le retour du réseau sur un téléphone représentatif.
- Pour le recensement, suivre `docs/installation-registration.md` : fermeture
  d'interface et arrêt forcé sont deux scénarios différents.
- Livrer un compte rendu daté des tests et les limitations. Une création d'artefact
  ne signifie pas publication, et une tâche WorkManager ne garantit pas un délai.

Le workflow manuel prépare un APK signé ; il ne publie pas sur Play Store.
Effectuer toute publication externe uniquement dans le périmètre autorisé.
