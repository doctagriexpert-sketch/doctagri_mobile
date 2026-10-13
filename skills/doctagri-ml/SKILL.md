---
name: doctagri-ml
description: Modifier ou évaluer les modèles, le prétraitement, la fusion et les règles d'abstention de DoctAgri avec vérification de parité Python et Flutter.
---

# Modifier le diagnostic IA

Lire `ml/README.md`, `lib/core/ml/`, le repository de diagnostic et
`ml/pipeline/app_inference.py` avant de modifier les transformations.

- Lire les types et dimensions réels des tenseurs : ne pas supposer 224 pixels
  ni une entrée float. Les modèles uint8 embarqués reçoivent les pixels bruts.
- Leurs sorties incluent déjà softmax : déquantifier puis normaliser. Ne pas
  écraser la confiance par un second softmax.
- Vérifier l'ordre des labels et le périmètre métier dans `culture_detector.dart`.
  Le modèle manioc embarqué ne prouve pas que le produit accepte actuellement le manioc.
- Distinguer détection de culture heuristique, confiance du modèle et probabilité
  empirique de justesse. Un seuil non calibré doit rester décrit comme tel.
- Tester refus sans feuille, culture hors périmètre, ambiguïté, faible confiance
  et sélection entre modèles. Les tests appellent les fonctions de production.
- Si les transformations changent, vérifier la parité sur les mêmes images entre
  Python et Flutter. Si le modèle ou un seuil change, enregistrer corpus, version,
  métriques par culture et coût d'abstention. Sans corpus étiqueté, annoncer la
  limite ; ne pas convertir une observation en promesse de précision.

Exécuter les tests de `test/unit/core/ml/` et
`test/unit/features/diagnosis/`, puis le contrôle Python. Une compilation seule
ne valide pas un diagnostic. Ne pas envoyer les photos de terrain à un fournisseur
externe pour étiquetage sans que cette utilisation soit autorisée.
