# Travailler sur DoctAgri

DoctAgri est une application agricole Flutter distribuée notamment par APK sur
le terrain. Le diagnostic local doit fonctionner sans réseau ni compte. Le
dashboard React et Supabase complètent ce parcours ; leur intégration est encore
partielle. Lire [l'état réel](docs/project-status.md), pas seulement les anciennes
présentations de l'architecture.

## Avant un changement

- Lire `git status --short` et préserver les modifications en cours.
- Lire [architecture](rules/architecture.md) et [qualité](rules/quality.md).
- Pour données, API ou configuration : lire [données et sécurité](rules/data-security.md).
- Pour livraison, migrations déployées ou APK : lire [livraison](rules/delivery.md).
- Définir le comportement attendu et les critères de réussite avant de coder.
  Pour un changement simple, quelques phrases suffisent ; pas de dossier de
  spécification systématique.

## Skills du dépôt

Ces skills sont versionnés dans `skills/`. Ouvrir le `SKILL.md` correspondant
lorsque le travail entre dans son périmètre ; ne pas charger tous les skills.
Ils ne nécessitent pas d'installation globale et ne remplacent pas la demande
de l'utilisateur.

| Travail | Procédure |
|---|---|
| Fonctionnalité ou correction mobile | [doctagri-mobile](skills/doctagri-mobile/SKILL.md) |
| Inférence, modèle ou qualité des diagnostics | [doctagri-ml](skills/doctagri-ml/SKILL.md) |
| Schéma, RLS, RPC ou synchronisation | [doctagri-supabase](skills/doctagri-supabase/SKILL.md) |
| APK, migration et préparation de livraison | [doctagri-release](skills/doctagri-release/SKILL.md) |

## Repères fiables

- Application effective : `lib/`, avec `data/domain/presentation` par fonctionnalité.
- Dashboard effectif : `doctagri-dashboard/`. `dashboard/` contient un autre
  historique SQL, pas l'application React courante.
- `packages/` est une modularisation amorcée, pas une architecture déjà migrée.
- Les migrations `supabase/` et `dashboard/supabase/` ne sont pas interchangeables.
- Les modèles quantifiés embarqués sortent déjà des probabilités : ne pas leur
  appliquer un second softmax. Voir `ml/README.md`.
- Les variables Flutter sont injectées à la compilation ; `.env` seul ne suffit pas.

## Vérifier et rendre compte

Utiliser `python scripts/quality.py --help` et la matrice de `rules/quality.md`.
Ne pas assouplir un contrôle pour obtenir du vert. Un contrôle non exécuté, une
erreur préexistante et une régression sont trois résultats différents.

À la fin : expliquer le comportement livré, les vérifications réellement
effectuées et les limites restantes. Une compilation ne démontre ni le
fonctionnement hors ligne sur appareil, ni la qualité agronomique du modèle,
ni le déploiement d'une migration.

Une décision transversale durable va dans `docs/decisions/` ; un défaut constaté
va dans `docs/technical-debt.md`. Mettre à jour la documentation affectée dans le
même changement. Ne pas créer une abstraction, un package, une file de messages
ou un service séparé sans besoin concret et mesurable.
