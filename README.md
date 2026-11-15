# DoctAgri & Terra-Orbit

**Plateforme intégrée d'intelligence agricole et spatiale pour les producteurs ruraux africains.**

DoctAgri réunit le diagnostic phytosanitaire mobile hors-ligne sur smartphone et l'observation spatiale par satellite avec le module **Terra-Orbit**, développé dans le cadre du défi **NASA Space Apps Challenge** (*Field Shift: Adapting Farms with NASA Data*).

---

## 🛰️ Terra-Orbit — NASA Space Apps Challenge

**Terra-Orbit** relie les données d'observation de la Terre de la NASA (NASA POWER, SMAP, ECOSTRESS) aux décisions culturales et financières des petits exploitants agricoles du Togo (Afrique de l'Ouest).

### Accès rapide pour les experts & évaluateurs NASA

* 📊 **Pitch Deck & Présentation Jury** :
  * [Version HTML Interactive (Plein écran, Chrono & Notes)](presentation-deck.html)
  * [Version Document PDF (Format 16:9 widescreen)](presentation-deck.pdf)
* 💻 **Simulateur Web Interactif** (`terra_orbit/web/`) :
  * Interface Next.js / TypeScript pour simuler la résilience hydrique et la rentabilité des rotations culturales sur les 392 cantons du Togo.
  * Lancement local :
    ```bash
    cd terra_orbit/web
    npm install
    npm run dev
    ```
* 📑 **Livres blancs & Dossier scientifique** (`terra_orbit/docs/`) :
  * [Dossier de soumission officiel NASA Space Apps](terra_orbit/docs/NASA_SPACE_APPS_OFFICIAL_SUBMISSION.md)
  * [Livre blanc agronomique & équations de rendement](terra_orbit/docs/AGRONOMIC_ENGINE_WHITE_PAPER.md)
  * [Méthodologie de downscaling satellitaire NASA SMAP/ECOSTRESS](terra_orbit/docs/REMOTE_SENSING_DOWNSCALING_WHITE_PAPER.md)
  * [Modèle économique & dé-risquage financier agricole](terra_orbit/docs/FINTECH_BUSINESS_MODEL_MIFA.md)
  * [Script de pitch 3 minutes](terra_orbit/docs/PITCH_DECK_3MIN.md)

---

## 📱 Application Mobile DoctAgri

Application mobile Flutter distribuée par APK pour le diagnostic de maladies des cultures par vision artificielle embarquée :
* **Inférence locale sans connexion** : Modèles TensorFlow Lite quantifiés (int8) exécutés directement sur l'appareil.
* **Résilience réseau** : Fonctionnement complet hors ligne (historique local Hive, photos, fiches de traitement).
* **Inclusion rurale** : Synthèse vocale et alertes SMS/audio en langues locales (Français, Éwé, Kabyè).

---

## 📂 Organisation du Dépôt

| Répertoire | Rôle |
|---|---|
| `terra_orbit/` | Module spatial & simulation de résilience agro-climatique (NASA Space Apps) |
| `terra_orbit/web/` | Application web interactive Next.js (simulateur de rotation et dashboard cantonal) |
| `terra_orbit/docs/` | Livres blancs scientifiques, méthodologies satellitaires et soumission NASA |
| `lib/`, `android/`, `ios/` | Application mobile Flutter et intégrations natives (diagnostic hors-ligne) |
| `doctagri-dashboard/` | Interface web d'annotation et de supervision agronomique |
| `ml/`, `assets/models/` | Pipeline d'entraînement Python et modèles embarqués TFLite |
| `rules/` | Règles d'architecture logicielle, sécurité des données et qualité |
| `docs/` | Spécifications des contrats d'API, décisions d'architecture (ADR) et runbooks |
| `hooks/`, `scripts/` | Outillage d'automatisation et scripts de contrôle qualité CI |

---

## 🚀 Démarrage Rapide

### 1. Simulateur Agro-Climatique (Terra-Orbit Web)

```bash
cd terra_orbit/web
npm install
npm run typecheck
npm test
npm run dev
```
Ouvrez [http://localhost:3000](http://localhost:3000) dans votre navigateur.

### 2. Application Mobile (Flutter)

```bash
flutter pub get
flutter run
```

### 3. Contrôles Qualité

```bash
python scripts/install_hooks.py
python scripts/quality.py repository
python scripts/quality.py all
```

---

## 📚 Documentation Complète

- [Architecture Système](docs/architecture/system-overview.md)
- [Guide de démarrage développeur](docs/getting-started.md)
- [Contrats de données environnementales](docs/contracts/terra-orbit-environment.md)
- [État réel du projet & transparence prototype](docs/project-status.md)
- [Suivi de la dette technique](docs/technical-debt.md)
- [Guide de contribution](CONTRIBUTING.md)

---

## ⚖️ Licence

Ce projet est sous licence [MIT](LICENSE).
