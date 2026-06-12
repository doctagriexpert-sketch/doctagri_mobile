# DoctAgri

**Diagnostic agricole par IA pour les agriculteurs africains**

[![Flutter](https://img.shields.io/badge/Flutter-3.10-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Phase](https://img.shields.io/badge/Phase-6%2F10-brightgreen.svg)](#)

DoctAgri est une application mobile de diagnostic des maladies des cultures par intelligence artificielle, conçue pour fonctionner hors-ligne et être utilisée par des agriculteurs dans des zones à faible connectivité.

## Fonctionnalités

- 📷 **Diagnostic par caméra** — Identification des maladies des cultures en quelques secondes
- 🤖 **IA embarquée multi-modèle** — Modèle spécialisé manioc + modèle PlantVillage multi-cultures (39 classes), quantifiés INT8, fusion avec détection de culture
- 📴 **Hors-ligne** — Fonctionne sans connexion internet
- 🔄 **Sync intelligente** — Synchronisation automatique quand connexion disponible
- 👩‍🔬 **Validation experte** — Possibilité de demander confirmation à un agronome
- 🌍 **Multi-langues** — Français, Ewe (Èʋegbe), Kabyè — avec lecture vocale (TTS)

## Architecture

```
doctagri/
├── lib/                  # Application Flutter
├── packages/             # Packages Dart isolés (Melos)
├── ml/                   # Pipeline ML (Python)
├── supabase/             # Migrations, Edge Functions
├── docs/                 # Documentation
└── .github/workflows/    # CI/CD
```

## Développement

### Prérequis

- Flutter 3.10+
- Dart 3.10+
- Python 3.10+ (pour ML pipeline)
- Node.js 18+ (pour dashboard React)

### Setup

```bash
# Installer dépendances Flutter
flutter pub get

# Installer lefthook (pre-commit hooks)
npm install -g lefthook
lefthook install

# Lancer analyse statique
dart analyze

# Lancer tests
flutter test

# Générer code injecté
dart run build_runner build --delete-conflicting-outputs
```

### Variables d'environnement

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Build

```bash
# APK debug
flutter build apk --debug

# APK release
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# App bundle (Play Store)
flutter build appbundle --release
```

## Tests

```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# Integration tests
flutter test test/integration/

# Coverage
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
```

## ML Pipeline

Le modèle est entraîné et exporté via le pipeline dans `ml/pipeline/`:

```bash
cd ml/pipeline
make all  # Run full pipeline
```

| Étape | Script | Description |
|-------|--------|-------------|
| 1 | `01_export_savedmodel.py` | Export Keras → SavedModel |
| 2 | `02_build_representative_dataset.py` | Dataset calibration |
| 3 | `03_quantize_int8.py` | Quantization INT8 |
| 4 | `04_validate_accuracy.py` | Validation accuracy |
| 5 | `05_benchmark_device.py` | Benchmark latence |
| 6 | `06_package_artifact.py` | Package final |

## Déploiement

### CI/CD Pipeline

- **PR Checks**: analyze, format, test, security scan
- **Build**: APK/IPA sur chaque PR
- **Staging**: Netlify + Firebase App Distribution
- **Production**: Google Play + App Store via tag Git

### Environments

| Environment | URL | Deploy Trigger |
|-------------|-----|---------------|
| Development | localhost | chaque push |
| Staging | staging.doctagri.com | PR merge |
| Production | doctagri.com | Tag `v*` |

## Monitoring

| Tool | Purpose |
|------|---------|
| [Sentry](https://sentry.io) | Crash reporting |
| [Grafana](https://grafana.com) | Metrics, dashboards |
| [PostHog](https://posthog.com) | Product analytics |

## Sécurité

- RLS (Row Level Security) sur Supabase
- Chiffrement au repos (pgsodium)
- Audit log sur toutes les opérations sensibles
- Obfuscation Dart en release
- Certificate pinning HTTPS

## Conformité RGPD

- Hébergement EU (Francfort)
- Export données utilisateur (droit à l'oubli)
- Consentement explicite à l'onboarding
- Privacy Manifest iOS

## Contributing

1. Créer une branche (`git checkout -b feature/my-feature`)
2. Commit (`git commit -m 'feat: add my feature'`)
3. Push (`git push origin feature/my-feature`)
4. Ouvrir une Pull Request

Voir [docs/contributing/](docs/contributing/) pour plus de détails.

## License

MIT License - voir [LICENSE](LICENSE) pour détails.

## Contact

- **Website**: [doctagri.com](https://doctagri.com)
- **Email**: contact@doctagri.com
- **Support**: support@doctagri.com

---

_Fait avec ❤️ pour les agriculteurs africains_
