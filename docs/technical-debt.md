# Dette technique suivie

État initial : 2 octobre 2026. P1 = bloque une capacité ou sa livraison fiable ;
P2 = nuit à la maintenance. Responsable à attribuer lors de la prise en charge,
pas de personne ou d'échéance fictive.

| ID | Priorité | Constat | Critère de résolution |
|---|---|---|---|
| DATA-01 | P1 | Payload mobile `diagnoses` incompatible avec migrations | Test d'insertion depuis le client sur schéma reconstruit + lecture de retour |
| DATA-02 | P1 | Deux historiques Supabase avec tables communes | ADR de convergence, inventaire du serveur cible, migration testée avec données |
| AUTH-01 | P1 | Sync exige session ; UI OTP non raccordée | Parcours choisi et testé, sans imposer un compte au diagnostic local |
| EXPERT-01 | P1 | Demandes de validation locales non reliées de bout en bout | Demande mobile visible et traitable par expert, résultat récupéré |
| ML-01 | P1 | Heuristiques et seuils partiellement non calibrés | Corpus terrain autorisé et étiqueté, métriques par culture, abstention mesurée |
| INSTALL-01 | P1 | Recensement non déployé et non testé physiquement | Migration/test SQL + APK signé + essais fermeture/redémarrage/réseau |
| INSTALL-02 | P2 | Inscription publique falsifiable et conservation non décidée | Protection contre abus testée et durée/purge validées avant diffusion large |
| PAY-01 | P1 avant paiement réel | PSP/webhook absent | Confirmation serveur authentifiée et test des reprises ; aucun succès fictif |
| MOD-01 | P2 | Packages Melos largement vides | Extraire seulement les modules utiles avec tests/consommateurs, ou retirer les squelettes |
| OBS-01 | P2 | Monitoring annoncé mais non démontré | Outil choisi, événements minimaux, accès et alertes vérifiés |
| QA-01 | Résolue localement | Contrôles locaux complets réussis le 13 octobre 2026 | Voir le rapport de correction ; CI distante non exécutée |
| QA-02 | P2 | Avertissement React Compiler pour TanStack Virtual et bundle dashboard de 517 ko | Compatibilité de la virtualisation vérifiée avant activation du compilateur ; découpage du bundle mesuré |

Pour ajouter une dette : fournir une preuve (fichier, test ou mesure), l'impact,
un critère de résolution et le lien de tâche/PR s'il existe. Lorsqu'elle est
résolue, consigner la preuve ; ne pas la fermer parce qu'un fichier a été créé.

QA-01 est désormais mesurée : 112 tests Flutter et 8 tests React réussis,
5 diagnostics Flutter, formatage à reprendre et 13 erreurs ESLint / 2 avertissements.
Voir [le rapport initial](verification/2026-10-02-engineering-foundation.md).

QA-01 : les erreurs bloquantes sont corrigées sans désactivation de règle.
Voir [la vérification du correctif](verification/2026-10-13-pre-push-fixes.md).


## Terra-orbit — constat et correction du 14 novembre 2026

- **TERRA-DATA (corrigé localement)** : anciennes réponses régionales, continuité sèche sur trous de données, températures fictives et humidité de secours non signalée. Preuves : `terra_orbit/web/tests/audit-regressions.test.cjs`. États liés aux coordonnées, valeurs nulles conservées, acquisition sol indépendante des onglets, scénario manuel explicite.
- **TERRA-MODEL (P1 avant usage terrain)** : `simulationEngine.ts` reste heuristique ; surface 0–1 cm, NDVI hypothétique, pente régionale et pluie saisonnière constante. Résolution 30 m, humidité racinaire, rendements et scoring financier non validés. Résolution : corpus parcellaire mesuré, calibration et comparaison avec une référence, incertitudes publiées.
- **TERRA-PYTHON (P2)** : moteurs Python et web divergents ; secours Python synthétique et entrées sol fixes. Résolution : choisir le moteur de référence puis tests de parité et provenance bout en bout. Ne pas annoncer une parité actuelle.
- **TERRA-DELIVERY (P1 avant service réel)** : SMS/USSD, paiements, assurance et traductions locales sont des démonstrations. Résolution : intégrations opérateurs testées, validation linguistique, décisions confirmées par les systèmes responsables. Les pitches historiques sont signalés comme non probants.

## Terra-orbit — réaudit du 15 novembre 2026

L'audit technique de préparation au jury recense les reproductions et les critères de résolution. Il remplace le statut antérieur uniquement sur les points explicitement rouverts ci-dessous.

- **TERRA-DATA (P1, rouvert)** : `web/src/app/page.tsx:74–97` réintroduit des constantes automatiques sans mode manuel ; résultats affichés quand les deux fournisseurs échouent. Résolution : provenance explicite et test de panne sans résultats implicites (A1).
- **TERRA-CMR (P1)** : `DownscalingPanel.tsx` conserve les granules précédents après erreur et affiche un succès ; les métadonnées ne sont pas des mesures ingérées. Résolution : états liés aux coordonnées, erreurs visibles et distinction catalogue/calcul (A2–A3).
- **TERRA-JURY (P1 avant soumission)** : documents revendiquant note, nomination et autorité de juge non attestées ; description HTML promettant du 30 m. Résolution : dossier conforme aux capacités démontrées, sources et limites par promesse (A3–A4).
- **TERRA-LOCATION (P2)** : homonymes sélectionnés par nom, GPS hors Togo accepté et précision non mesurée affichée. Résolution : identifiants uniques, validation géographique commune, provenance et précision explicites (A5).
- **TERRA-AUDIO (P2)** : bouton « Écouter » du simulateur affichant seulement un texte fixe. Résolution : lecture du conseil courant vérifiée ou fonction renommée en aperçu (A6).
- **TERRA-QA (P2)** : lint non configuré, absence de job Terra Orbit dans les workflows examinés et test de page acceptant le secours silencieux. Résolution : contrôles non interactifs, scénarios d'erreur et version de démonstration reproductible (A7–A8).
- **TERRA-COMPARE (P1 avant démonstration des gains)** : les nouvelles cartes de recommandations omettent la météo transmise au scénario principal ; une même rotation donne 45,2 contre 51,7 dans la reproduction avec sécheresse. Résolution : contexte identique pour tous les appels et test d'égalité des résultats pour le plan actif, avec météo complète. Séquences et écarts documentés dans les contrats de simulation.
