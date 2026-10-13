# ADR 0001 — Cadre d'ingénierie du dépôt

Statut : adopté pour le développement local, 2 octobre 2026.

## Contexte

Flutter, React, SQL et ML coexistent avec de la documentation prospective, des
packages amorcés et des workflows divergents. Le projet est distribué sur le
terrain sans compte ni connexion préalable.

## Décision

- Conserver l'architecture effective et ses frontières ; éviter une migration
  générale vers les packages ou des microservices sans besoin mesuré.
- Centraliser les règles dans `rules/`, les procédures d'assistance dans
  `skills/`, les contrôles dans `hooks/` et `scripts/`, la connaissance dans `docs/`.
- Faire de `AGENTS.md` le routeur des instructions, sans installation globale.
- Utiliser les mêmes commandes de qualité en local et dans GitHub Actions.
  Le hook rapide examine l'index ; les contrôles complets restent en CI/pre-push.
- Conserver les échecs visibles et suivre la dette ; ne pas assouplir les seuils
  de lint pour afficher un succès artificiel.
- Préparer les releases Android manuellement tant que signature, serveur et
  scénario terrain ne sont pas validés. Le dashboard conserve son déploiement
  Netlify existant après les contrôles.

## Conséquences

Python standard suffit aux contrôles du dépôt ; Flutter et Node restent nécessaires
à leurs suites. Les hooks locaux sont contournables : la protection de branche
doit exiger les checks CI côté GitHub. Cette protection ne peut pas être imposée
par un simple fichier commité.

Les skills sont lus via `AGENTS.md` ; leur présence à la racine n'affirme pas
qu'ils sont installés dans tous les catalogues d'outils. Les skills de sécurité
locaux préexistants restent distincts.

Reconsidérer cette décision si une équipe/module nécessite un cycle de publication
autonome ou si des mesures justifient un découpage supplémentaire.
