# Architecture effective

État observé le 2 octobre 2026, sans certification d'un déploiement distant.

```text
Photo → Flutter → TFLite → règles de qualité → conseil + historique Hive
                                                    │
                                                file locale
                                                    │ réseau + session
                                                    ▼
                                                 Supabase
Dashboard React → Supabase (images, annotations, conflits, fiches, produits)
```

## Mobile

lib/main.dart initialise Hive et l'injection puis affiche l'interface et charge
les services/modèles. Provider gère l'état ; GoRouter, la navigation.
lib/features/diagnosis/ sépare data/domain/presentation. Les autres fonctionnalités
couvrent caméra, conseils, météo et commandes.

Les modèles manioc et PlantVillage sont exécutés localement. Prétraitement selon
type/dimensions du tenseur, déquantification, traitement des probabilités,
filtrage de culture et abstention précèdent le conseil. Ne pas appliquer un
second softmax à une sortie déjà probabiliste.

La synchronisation exige actuellement une session ; son contrat diffère du SQL
versionné. Une demande experte locale ne prouve pas sa réception par le dashboard.

## Recensement Android

Un canal Flutter programme un Worker Kotlin WorkManager. Il conserve un UUID hors
sauvegardes et envoie une inscription minimale sans compte, indépendamment du
diagnostic. Voir [le contrat](../contracts/app-installations.md).

## Dashboard et SQL

React/Vite : doctagri-dashboard/. Historique d'annotation : dashboard/supabase/.
Historique mobile : supabase/. Des tables communes diffèrent : leur convergence
reste une décision explicite, pas une application automatique des deux ensembles.

## Croissance

Les packages Melos ne portent pas encore toute l'application. Consolider les
frontières dans lib/ avant d'extraire des modules réellement réutilisés.
Performance, couverture, précision et charge doivent être mesurées.
Voir [l'état du projet](../project-status.md).
