# Correction des contrôles pre-push — 13 octobre 2026

## Comportement et corrections

Objectif : réussir les contrôles locaux bloquant le push sans réduire leur portée.

- Déclaration des dépendances image, hive et equatable dans le manifeste des tests.
- Formatage des 36 fichiers Dart signalés, sans modifier les fichiers générés.
- Ajout des accolades exigées après formatage dans deux conditions existantes.
- Chargements React déclarés avant utilisation, callbacks stables et mises à jour
  des listes effectuées après réception des réponses Supabase.
- Séparation du hook useAuth et du fournisseur React pour Fast Refresh ; imports
  et mock de test mis à jour.
- Initialisation paresseuse du chronomètre et dépendances complètes du raccourci
  Ctrl+Entrée : la soumission utilise le profil courant après un nouveau rendu.
- Suppression des variables inutilisées et références explicites aux icônes JSX.

## Vérifications

`python scripts/quality.py all` réussit :

- Garde du dépôt, liens documentaires et 9 tests Python réussis.
- Analyse Flutter sans diagnostic ; 73 fichiers contrôlés, aucun à reformater.
- 112 tests Flutter réussis.
- ESLint : aucune erreur, un avertissement TanStack Virtual conservé.
- 9 tests React réussis, dont la régression du raccourci et son nettoyage au démontage.
- Compilation Vite réussie ; avertissement de bundle supérieur à 500 ko conservé.
- Vérification syntaxique Python réussie.
- Test de régression exécuté sur l’ancien composant : échec confirmé, car
  expert-1 était envoyé au lieu du profil courant expert-2. Avec le correctif,
  le même test réussit.

## Limites

Aucun push, déploiement, test physique hors ligne ni mesure agronomique effectué.
Le contrôle local ne prouve pas les droits GitHub ni la réussite de la CI distante.
Les avertissements non bloquants sont suivis dans QA-02 de la dette technique.
