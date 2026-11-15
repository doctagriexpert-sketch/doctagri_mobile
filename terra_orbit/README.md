# TERRA-ORBIT TOGO

Prototype de comparaison de scénarios agricoles au Togo. Les résultats sont exploratoires et nécessitent une validation terrain. Aucun financement, paiement, contrat d’assurance, SMS ou USSD réel n’est exécuté.

## État actuel

- **Web Next.js** (`web/`) : charge NASA POWER et Open-Meteo dès l’ouverture, indépendamment des onglets. Les réponses d’une ancienne région sont invalidées et les requêtes annulées.
- **Météo** : 30 jours calendaires terminant à J−5. Les valeurs absentes restent `null`, interrompent la courbe et les séquences sèches. La couverture est affichée. La pénalité de sécheresse du premier cycle n’est appliquée que si tous les jours de pluie sont renseignés.
- **Sol** : humidité de surface 0–1 cm et température de surface horaires du modèle Open-Meteo, en sélection automatique. Aucun produit SMAP, ECOSTRESS, SRTM ou Sentinel-2 n’est téléchargé. Le NDVI est hypothétique et la pente est régionale. La résolution de 30 m et l’humidité racinaire ne sont pas validées.
- **Indisponibilité** : aucun remplacement silencieux par des constantes. Sans données sol, les estimations sont suspendues ; l’utilisateur peut explicitement activer un scénario manuel. Toute modification d’un curseur passe en mode manuel.
- **Rotation** : calculs heuristiques, précédents culturaux, réserve d’eau et hypothèses saisonnières. Le cumul des pluies historiques est affiché, sans extrapolation en prévision saisonnière ni ajout à la réserve actuelle (risque de double comptage).
- **Finance** : taux, seuils et montants hypothétiques, sans calibration bancaire. L’identifiant web `auditFingerprint` est déterministe et non cryptographique ; il ne prouve aucune transaction.
- **Python/Streamlit** (`app.py`) : démonstration distincte, non équivalente au web. Le secours météo est synthétique, le sol utilise des constantes, et les calculs agronomiques diffèrent. Les messages d’assurance sont des aperçus non envoyés. Les traductions financières non validées utilisent un aperçu français.

## Vérification locale

Depuis `terra_orbit/web` :

```sh
npm run typecheck
npm test
npm run build
npm run dev
```

Depuis la racine du dépôt, le test financier sans dépendance externe :

```sh
python -B -m unittest terra_orbit.tests.test_simulation_disclosure -v
```

Les anciennes suites scientifiques requièrent notamment `pytest`, `numpy`, `pandas` et `requests`. Leur réussite ne constitue pas une validation agronomique.

## Sources et limites

- [NASA POWER](https://power.larc.nasa.gov/docs/methodology/) : produits météorologiques et satellitaires.
- [Open-Meteo](https://open-meteo.com/en/docs) : `soil_moisture_0_to_1cm`, `soil_temperature_0cm`, prévisions horaires.
- [Contrat des données](../docs/contracts/terra-orbit-environment.md).
- [Dette et critères de validation](../docs/technical-debt.md).

Les documents de pitch et livres blancs dans `docs/` décrivent une ambition historique ; leurs annonces de certification, de partenariat et de résolution ne constituent pas des preuves de capacités livrées. Aucune nomination NASA n’est attestée par ce dépôt.
