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
