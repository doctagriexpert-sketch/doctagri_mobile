# Terra-orbit : données régionales du prototype

## Acquisition et états

Les routes GET `nasa-power` et `satellite-soil-moisture` attendent `lat` et `lon` numériques dans les limites géographiques. Une entrée invalide donne 400 ; un fournisseur indisponible, une réponse inexploitable ou périmée donne 502. Le délai fournisseur est limité à 10 secondes, le délai navigateur à 15 secondes. Aucun secret, compte, paiement ni persistance de coordonnées n’est ajouté.

`useRegionalEnvironment` charge les deux sources dès le montage. Chaque état est attaché à la paire de coordonnées. Changement de région : anciennes requêtes annulées et réponses tardives ignorées ; le rendu masque les anciennes données avant même le prochain effet React. Les états sont `loading`, `ready`, `error`, séparés par source.

## NASA POWER

Période UTC de 30 jours inclusifs, terminée cinq jours avant la requête. Chaque date demandée apparaît même si elle manque chez le fournisseur. `rainMm`, `tempMean`, `tempMin`, `tempMax`, `solarRadiation` sont numériques ou `null`. Aucune interpolation. Une date inconnue interrompt une séquence sèche ; les valeurs sous 2 mm sont considérées sèches par l’heuristique existante.

`validDaysCount` compte les jours où les cinq variables sont disponibles. `summary.validRainDaysCount` compte seulement les pluies connues. `summary.totalRainMm` est le cumul sur ces jours ou `null` si aucun ; `maxDrySpellDays` est la plus longue séquence confirmée ou `null`. Le moteur ne prend la pénalité de sécheresse en compte que pour une période de pluie complète. Le cumul est descriptif, sans projection future.

## Open-Meteo

La route conserve son ancien nom mais renvoie un modèle, pas un flux satellitaire. Variables horaires documentées : `soil_moisture_0_to_1cm` et `soil_temperature_0cm`, heure courante en UTC, sélection automatique des modèles. `soilMoistureM3M3` et `surfaceTempC` doivent être finis et plausibles ; zéro est une valeur valide. `asOf` doit dater de moins de deux heures et ne pas être futur. Aucun remplacement par 0,16 ou T2m + 3,2.

Le modèle de surface n’est pas validé comme estimation racinaire. NDVI 0,52 et pente régionale sont explicitement des hypothèses. Une modification utilisateur bascule l’ensemble des entrées sol en scénario manuel. Sans source sol ni action manuelle explicite, les estimations et décisions simulées sont suspendues.

## Finance et compatibilité

Le champ web trompeur `sha256Hash` est remplacé par `auditFingerprint`. Identifiant non cryptographique de scénario incluant capital, anomalies, durée, bénéficiaire, opérateur, montant et date ; aucune preuve de paiement. Les APIs fournisseur changent de contrat uniquement avec leurs consommateurs web dans ce dépôt. Aucun consommateur externe n’est attesté.

Python reste une autre démonstration. Ses messages et payloads d’assurance indiquent `SIMULATION_ONLY` et aucun transfert. La précision des modèles, l’intégration satellitaire et les traductions restent à valider.
