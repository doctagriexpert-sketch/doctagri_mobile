# DoctAgri — Setup Démo

Guide rapide pour faire tourner la démo Phase 3 en local.

## Prérequis

- Flutter SDK >= 3.10.4 (Dart 3)
- Un émulateur Android / device physique (USB debug) ou iOS Simulator
- Supabase CLI (optionnel, pour appliquer les migrations)
- Un fichier `.env` à la racine (copier `.env.example`) avec les clés Supabase et Open-Meteo

## Lancer l'app

```bash
flutter pub get
flutter run
```

Pour un build de démo release :

```bash
flutter run --release
```

## Appliquer les migrations Supabase

### Option A — Supabase CLI (recommandé)

Depuis la racine du projet :

```bash
supabase db push
```

Cela applique en ordre toutes les migrations de `supabase/migrations/`, dont la dernière :
`20260421000000_products_and_orders.sql` (catalogue produits + commandes mobile money).

### Option B — Application manuelle

1. Ouvrir le dashboard Supabase > SQL Editor.
2. Copier-coller le contenu de `supabase/migrations/20260421000000_products_and_orders.sql`.
3. Exécuter. Les tables `products` et `orders` sont créées avec RLS et 3 produits seed.

## Endpoints utilisés

| Service | URL / Source | Usage |
|---|---|---|
| Open-Meteo | `https://api.open-meteo.com/v1/forecast` | Météo locale (pas de clé requise) |
| Supabase | `SUPABASE_URL` depuis `.env` | Auth, diagnoses, orders, storage |
| YouTube | `https://www.youtube.com/watch?v=<id>` | Capsules vidéo conseils (via `youtube_player_flutter`) |
| OpenWeather | `OPEN_WEATHER_API_KEY` depuis `.env` | Fallback météo (legacy, optionnel) |

## Variables d'environnement clés

Dans `.env` :

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
OPEN_WEATHER_API_KEY=<optional>
```

## Limitations connues de la démo

- **Paiement simulé** : aucune intégration réelle MTN / Moov / Orange Money. L'ordre est inséré
  en base avec `status = 'pending'` puis passe à `paid` après un délai factice. Ne jamais
  déployer en prod sans gateway réelle.
- **Vidéos YouTube externes** : les capsules conseils pointent vers des URLs YouTube publiques.
  Nécessite connexion internet ; certaines vidéos peuvent être géo-bloquées.
- **Modèle TFLite 6 classes** : le modèle déployé ne couvre que 6 classes (les 20 labels de
  `labels.txt` ne sont pas tous actifs). Voir la memory projet pour détails.
- **Open-Meteo** : pas de rate-limit contract ; pour la prod envisager un cache côté serveur.
- **Géoloc** : requiert permission utilisateur runtime ; fallback = coordonnées par défaut
  d'une région agricole témoin si refus.
