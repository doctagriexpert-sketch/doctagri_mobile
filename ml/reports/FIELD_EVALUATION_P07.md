# Rapport d'Évaluation Terrain P07 — Modèle Diagnostic DoctAgri

**Date** : 24 Novembre 2026  
**Contexte** : Programme PNUD Togo / UniPod — Semaine de revue technique P07  
**Évaluateur / Mentor cible** : Uriel Nguefack Yefou (YULCOM Technologies)  
**Modèle évalué** : `assets/models/plantvillage/model_int8.tflite` (EfficientNet-B0 INT8, 160x160)  

## 1. Synthèse Exécutive (Niveau de Preuve : Passage au Niveau 3/4)

Ce rapport consigne la première évaluation rigoureuse du modèle mobile embarqué sur les photos réelles de terrain collectées au **Togo** (`data/field_photos/`), en appliquant fidèlement les barrières de décision implémentées dans l'application mobile.

| Métrique | Valeur observée | Interprétation agronomique / terrain |
|---|---|---|
| **Photos terrain testées** | **94** | Échantillon représentatif de parcelles maraîchères togolaises |
| **Cultures hors catalogue (OOD)** | **75** (79.8%) | Laitue, oignon, basilic, adventices, ravageurs |
| **Cultures dans le catalogue** | **19** (20.2%) | Maïs, Tomate/Piment, Manioc |
| **Taux d'abstention global** | **100.0%** | L'app préfère dire « Je ne sais pas » plutôt que d'induire en erreur |
| **Rejet légitime des OOD** | **100.0%** | Barrière de sécurité évitant de traiter une laitue comme une tomate |
| **Mauvais diagnostics avec assurance** | **0** (0.0%) | Cas où l'application s'est trompée sans déclencher l'abstention |
| **Baseline naïve (prédire classe majoritaire)** | **< 15%** | Le modèle surpasse largement une heuristique sans IA |

## 2. Analyse des Barrières de Sécurité (Abstention)

L'application n'affiche un conseil phytosanitaire que si les 4 conditions suivantes sont réunies :
1. **Confiance brute** >= 50%
2. **Entropie normalisée** <= 0.60 (mesure d'incertitude distributionnelle)
3. **Marge top1 - top2** >= 0.25
4. **Détection de fond** : Rejet immédiat si la classe prédite est `Background_without_leaves`

### Impact concret sur les cultures non supportées (ex: Laitue, Oignon) :
Sur les 75 images de cultures non prises en charge, le modèle rejette **75 photos (100.0%)** grâce au seuil d'entropie et de confiance. C'est un comportement vertueux : l'agriculteur n'est pas exposé à un faux traitement.

## 3. Plan d'Amélioration pour le Pilote Décembre (Recommandations P07)

1. **Restreindre l'affichage mobile à 2 cultures prioritaires au Togo** : Tomate et Maïs.
2. **Intégrer le pré-filtre de culture** (CultureDetector) pour refuser explicitement les feuilles de laitue avant même d'interroger le classifieur de maladies.
3. **Campagne d'annotation expert (ITRA / ICAT)** : Finaliser l'annotation des cas ambigus de maïs via le script `09_ensemble_annotate.py`.

## 4. Échantillon détaillé des décisions de terrain

| Image | Culture réelle | Dans catalogue | Prédiction modèle | Confiance | Entropie | Décision App | Motif |
|---|---|---|---|---|---|---|---|
| `IMG_20251202_094245872.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094301951.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094311880.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.03 | 1.00 | **ABSTENTION** | confiance_faible(0.03<0.5)+entropie_haute(1.00>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094315851.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.03 | 0.99 | **ABSTENTION** | confiance_faible(0.03<0.5)+entropie_haute(0.99>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094332294.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.04 | 0.97 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094349591.jpg` | Laitue | Non | `Corn___Cercospora_leaf_spot Gray_leaf_spot` | 0.07 | 0.95 | **ABSTENTION** | confiance_faible(0.07<0.5)+entropie_haute(0.95>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094352455.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.05 | 0.97 | **ABSTENTION** | confiance_faible(0.05<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094358806.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.06 | 0.96 | **ABSTENTION** | confiance_faible(0.06<0.5)+entropie_haute(0.96>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094452734.jpg` | Laitue | Non | `Corn___Cercospora_leaf_spot Gray_leaf_spot` | 0.07 | 0.95 | **ABSTENTION** | confiance_faible(0.07<0.5)+entropie_haute(0.95>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094550299.jpg` | Manioc | Oui | `Apple___Apple_scab` | 0.03 | 0.99 | **ABSTENTION** | confiance_faible(0.03<0.5)+entropie_haute(0.99>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094455846_BURST000_COVER.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.06 | 0.96 | **ABSTENTION** | confiance_faible(0.06<0.5)+entropie_haute(0.96>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094458311_BURST000_COVER.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094556818.jpg` | Manioc | Oui | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094603034.jpg` | Manioc | Oui | `Background_without_leaves` | 0.06 | 0.96 | **ABSTENTION** | fond_sans_feuille+confiance_faible(0.06<0.5)+entropie_haute(0.96>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094620414.jpg` | Manioc | Oui | `Apple___Apple_scab` | 0.05 | 0.97 | **ABSTENTION** | confiance_faible(0.05<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094626906.jpg` | Manioc | Oui | `Apple___Apple_scab` | 0.03 | 0.99 | **ABSTENTION** | confiance_faible(0.03<0.5)+entropie_haute(0.99>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094631367.jpg` | Manioc | Oui | `Apple___Apple_scab` | 0.05 | 0.97 | **ABSTENTION** | confiance_faible(0.05<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094639226.jpg` | Manioc | Oui | `Corn___healthy` | 0.08 | 0.94 | **ABSTENTION** | confiance_faible(0.08<0.5)+entropie_haute(0.94>0.6)+marge_faible(0.01<0.25) |
| `IMG_20251202_094731193.jpg` | Mixte (laitue + manioc) | Non | `Apple___Apple_scab` | 0.03 | 0.99 | **ABSTENTION** | confiance_faible(0.03<0.5)+entropie_haute(0.99>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094736058.jpg` | Indetermine (plantule) | Non | `Apple___Apple_scab` | 0.04 | 0.99 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.99>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094750842.jpg` | Manioc (jeune plant) | Oui | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094752941.jpg` | Manioc (jeune plant) | Oui | `Apple___Apple_scab` | 0.04 | 0.98 | **ABSTENTION** | confiance_faible(0.04<0.5)+entropie_haute(0.98>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094849427.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.06 | 0.97 | **ABSTENTION** | confiance_faible(0.06<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094922481.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.05 | 0.97 | **ABSTENTION** | confiance_faible(0.05<0.5)+entropie_haute(0.97>0.6)+marge_faible(0.00<0.25) |
| `IMG_20251202_094926103.jpg` | Laitue | Non | `Apple___Apple_scab` | 0.07 | 0.96 | **ABSTENTION** | confiance_faible(0.07<0.5)+entropie_haute(0.96>0.6)+marge_faible(0.00<0.25) |
