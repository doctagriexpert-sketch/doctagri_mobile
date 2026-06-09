# DoctAgri — Documentation Technique

> Version 1.2 — Mai 2026  
> Audience : équipe de développement (Flutter, ML, backend)

---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture générale](#2-architecture-générale)
3. [Structure des dossiers](#3-structure-des-dossiers)
4. [Pipeline ML embarqué](#4-pipeline-ml-embarqué)
   - 4.1 [Modèles TFLite](#41-modèles-tflite)
   - 4.2 [ModelProfile & ModelCatalog](#42-modelprofile--modelcatalog)
   - 4.3 [ModelManager — chargement multi-modèle](#43-modelmanager--chargement-multi-modèle)
   - 4.4 [Prétraitement des images](#44-prétraitement-des-images)
   - 4.5 [Stratégie d'inférence multi-modèle](#45-stratégie-dinférence-multi-modèle)
5. [Base de connaissances des maladies](#5-base-de-connaissances-des-maladies)
   - 5.1 [Schéma JSON](#51-schéma-json)
   - 5.2 [DiseaseInfo — entité domaine](#52-diseaseinfo--entité-domaine)
6. [Système multilingue & TTS](#6-système-multilingue--tts)
   - 6.1 [LanguageService](#61-languageservice)
   - 6.2 [VoiceService](#62-voiceservice)
   - 6.3 [DiagnosisExplanationBuilder](#63-diagnosisexplanationbuilder)
   - 6.4 [TranslationService — traduction NLLB-200](#64-translationservice--traduction-nllb-200)
7. [Feature Diagnostic (bout en bout)](#7-feature-diagnostic-bout-en-bout)
   - 7.1 [DiagnosisRepositoryImpl](#71-diagnosisrepositoryimpl)
   - 7.2 [DiagnosisProvider](#72-diagnosisprovider)
   - 7.3 [Pages et widgets](#73-pages-et-widgets)
8. [Autres features](#8-autres-features)
9. [Services transverses](#9-services-transverses)
10. [Navigation (go_router)](#10-navigation-go_router)
11. [Injection de dépendances (injectable + GetIt)](#11-injection-de-dépendances-injectable--getit)
12. [Backend Supabase](#12-backend-supabase)
13. [Pipeline Python ML (hors app)](#13-pipeline-python-ml-hors-app)
14. [Packages Dart isolés](#14-packages-dart-isolés)
15. [Comment ajouter un nouveau modèle TFLite](#15-comment-ajouter-un-nouveau-modèle-tflite)
16. [Comment ajouter une entrée de maladie](#16-comment-ajouter-une-entrée-de-maladie)
17. [Déploiement et limitations connues](#17-déploiement-et-limitations-connues)

---

## 1. Vue d'ensemble

**DoctAgri** est une application mobile Flutter destinée aux agriculteurs d'Afrique de l'Ouest. Elle permet de diagnostiquer les maladies des cultures en prenant simplement une photo d'une feuille. Le résultat est présenté en texte clair et lu automatiquement à voix haute dans la langue de l'utilisateur (français, éwé ou kabyè).

### Principes directeurs

| Principe | Implémentation |
|---|---|
| **Offline-first** | Inférence locale TFLite + stockage Hive + file de sync |
| **Accessibilité rurale** | TTS automatique, interface iconographique, faible consommation réseau |
| **Multi-cultures** | Deux modèles embarqués couvrant manioc + 14 autres cultures |
| **Multilinguisme** | Français (FR), Éwé (EE), Kabyè (KAB) ; traductions Éwé via NLLB-200 |
| **Extensibilité** | Catalogue de modèles déclaratif — ajouter un modèle = 4 fichiers |

### Stack technologique

```
Flutter 3.x / Dart 3.10
  ├── tflite_flutter 0.12.1   — inférence on-device
  ├── flutter_tts 4.2.3       — synthèse vocale
  ├── speech_to_text 7.1.0    — reconnaissance vocale
  ├── share_plus 10.1.4       — partage image + texte (WhatsApp expert)
  ├── provider 6.1.5          — state management
  ├── injectable + get_it     — injection de dépendances
  ├── go_router 14.8.1        — navigation déclarative
  ├── hive 2.2.3              — persistance locale chiffrée
  └── supabase_flutter 2.8.0  — backend auth + sync

Python 3.12 (pipeline ML hors app)
  ├── tensorflow 2.x          — entraînement + export
  └── tflite                  — quantification INT8

Supabase (backend cloud)
  ├── PostgreSQL + RLS        — base de données sécurisée
  ├── Storage                 — images diagnostics
  ├── Edge Functions (Deno)   — translate (NLLB-200), notifications, exports RGPD
  └── Realtime                — sync push
```

---

## 2. Architecture générale

L'application suit la **Clean Architecture** à trois couches (domain → data → presentation) organisée par feature. Les dépendances ne pointent que vers le centre (domaine).

```
┌─────────────────────────────────────────────────────┐
│                  PRESENTATION                        │
│   Pages · Providers (ChangeNotifier) · Widgets       │
├─────────────────────────────────────────────────────┤
│                    DOMAIN                            │
│   Entities · Use Cases · Repository interfaces       │
├─────────────────────────────────────────────────────┤
│                     DATA                             │
│   Repository impls · Data sources · Models JSON      │
└─────────────────────────────────────────────────────┘
           ↓ cross-cutting concerns
┌─────────────────────────────────────────────────────┐
│                    CORE                              │
│  ML · Services · Router · DI · Constants · Errors   │
└─────────────────────────────────────────────────────┘
```

Les `Provider`s Flutter (via `ChangeNotifier`) constituent la couche de state management. Ils appellent des use cases ou des repositories, jamais de sources de données directement.

---

## 3. Structure des dossiers

```
doctagri/
├── lib/
│   ├── main.dart                     # Point d'entrée — init critique + background
│   ├── app.dart                      # MaterialApp + localisation
│   ├── injection_container.dart      # Déclaration GetIt
│   ├── injection_container.config.dart  # Généré par build_runner
│   ├── core/
│   │   ├── constants/                # Couleurs, typographie, spacing, radius
│   │   ├── di/                       # register_module.dart (Hive boxes async)
│   │   ├── errors/                   # Failure classes (CacheFailure, ModelFailure…)
│   │   ├── ml/
│   │   │   ├── model_manager.dart    # ModelProfile, ModelCatalog, ModelManager
│   │   │   ├── image_preprocessor.dart  # Resize + normalize en isolate
│   │   │   ├── crop_registry.dart    # Mapping culture → modèle
│   │   │   └── model_registry.dart   # Lecture de registry.json
│   │   ├── presentation/
│   │   │   ├── app_shell.dart        # BottomNavBar + ShellRoute
│   │   │   └── splash_screen.dart    # Init models + services
│   │   ├── router/
│   │   │   └── app_router.dart       # GoRouter — toutes les routes
│   │   ├── services/
│   │   │   ├── language_service.dart # AppLanguage enum + traductions
│   │   │   ├── voice_service.dart    # TTS + STT + état speaking/listening
│   │   │   ├── supabase_service.dart # Auth + upload + requêtes REST + Edge Functions
│   │   │   ├── translation_service.dart  # NLLB-200 via Edge Function + cache Hive
│   │   │   ├── sync_queue.dart       # File Hive des ops en attente
│   │   │   ├── sync_service.dart     # Orchestrateur offline→online
│   │   │   └── feature_flag_service.dart  # Flags runtime
│   │   ├── themes/                   # ThemeData light
│   │   ├── usecases/                 # UseCase<T,P> base class
│   │   ├── utils/                    # Helpers (date, string…)
│   │   └── widgets/                  # Widgets partagés (LoadingOverlay…)
│   ├── features/
│   │   ├── camera/                   # Capture image
│   │   ├── diagnosis/                # Diagnostic IA (feature principale)
│   │   ├── home/                     # Écran d'accueil
│   │   ├── advice/                   # Conseils culturaux
│   │   ├── weather/                  # Météo locale
│   │   └── payment/                  # Paiement Mobile Money (Togo)
│   ├── shared/
│   │   └── widgets/                  # LanguageSelector, TactileCard
│   └── l10n/                         # Fichiers ARB (en/fr)
├── assets/
│   ├── models/
│   │   ├── model.tflite              # Modèle cassava (6 classes, 224×224)
│   │   ├── labels.txt                # Labels cassava (1 par ligne)
│   │   ├── model_backup.tflite       # Sauvegarde avant quantification
│   │   ├── registry.json             # Catalogue lisible des modèles
│   │   └── plantvillage/
│   │       ├── model_int8.tflite     # Modèle PlantVillage (39 classes, 160×160)
│   │       └── class_names.json      # Labels PlantVillage (JSON array)
│   ├── data/
│   │   ├── diseases_knowledge.json   # Base de connaissances (45 maladies)
│   │   └── crop_tips.json            # Conseils culturaux par culture
│   └── images/
│       └── logo.png
├── ml/                               # Pipeline Python (hors app)
│   ├── pipeline/                     # Scripts 01→06 + Makefile
│   ├── build_plantvillage_knowledge.py
│   ├── datasets/representative/      # Données de calibration INT8
│   └── models/                       # Modèles intermédiaires (.keras, .pb…)
├── supabase/
│   ├── migrations/                   # SQL versionné
│   └── functions/
│       └── translate/                # Edge Function NLLB-200 (Deno)
│           └── index.ts
├── packages/                         # Packages Dart isolés (melos)
└── docs/                             # Documentation
```

---

## 4. Pipeline ML embarqué

### 4.1 Modèles TFLite

Deux modèles sont embarqués dans l'APK/IPA :

| ID | Fichier | Classes | Entrée | Type | Taille | Source |
|---|---|---|---|---|---|---|
| `cassava` | `assets/models/model.tflite` | 6 | 224×224 uint8 | MobileNetV3 | ~8 MB | Entraînement interne |
| `plantvillage` | `assets/models/plantvillage/model_int8.tflite` | 39 | 160×160 uint8 | MobileNet INT8 | ~4.9 MB | HuggingFace `Ashish094562/Plant-Disease-INT8-model` |

**Classes cassava** (6) : CBB, CBSD, CGM, CMD, Healthy, Unknown  
**Classes PlantVillage** (39) : Tomate (10 classes), Maïs (4), Pomme de terre (3), Piment (2), Apple (3), Cerise (2), Vigne (4), Orange (1), Pêche (1), Fraise (2), Soja (1), Courge (1), Framboise (1), Myrtille (1), `Background_without_leaves` (1)

> **Classe spéciale** : `Background_without_leaves` signale que la photo ne contient pas de feuille analysable. Le code la détecte et retourne "Image inutilisable" plutôt qu'un faux diagnostic.

### 4.2 ModelProfile & ModelCatalog

**Fichier** : `lib/core/ml/model_manager.dart`

`ModelProfile` est une structure immutable décrivant un modèle :

```dart
class ModelProfile {
  final String id;              // identifiant unique ('cassava', 'plantvillage')
  final String displayName;     // nom affiché à l'utilisateur
  final String assetPath;       // chemin du .tflite dans les assets
  final String labelsAssetPath; // chemin des labels (.txt ou .json)
  final int inputSize;          // dimension carrée (ex. 160 ou 224)
  final List<double> mean;      // normalisation (ignorée pour les modèles uint8)
  final List<double> std;       // normalisation (ignorée pour les modèles uint8)
  final List<String> cultures;  // cultures couvertes (ex. ['Tomate', 'Maïs'])
}
```

`ModelCatalog` déclare statiquement tous les profils connus :

```dart
class ModelCatalog {
  static const ModelProfile cassava     = ModelProfile(id: 'cassava', ...);
  static const ModelProfile plantVillage = ModelProfile(id: 'plantvillage', ...);
  static const ModelProfile defaultProfile = plantVillage;   // actif par défaut
  static const List<ModelProfile> all = [plantVillage, cassava];
}
```

Pour ajouter un modèle, il suffit d'ajouter un `ModelProfile` à `ModelCatalog.all` — tout le reste (chargement, inférence, sélection) est automatique.

### 4.3 ModelManager — chargement multi-modèle

**Fichier** : `lib/core/ml/model_manager.dart`  
**Classe** : `ModelManager` (singleton `ModelManager.instance`)

`ModelManager.initialize()` charge **tous les profils en parallèle** via `Future.wait()` pour minimiser le temps de démarrage. Il est appelé depuis `_initBackground()` dans `main.dart` afin de ne pas bloquer l'affichage de l'interface :

```
initialize()
  ├── Future.wait() sur tous les profils de ModelCatalog.all :
  │     (chargement simultané — ~40 % plus rapide que séquentiel)
  │     Pour chaque profile :
  │       ├── Interpreter.fromAsset(profile.assetPath)  [TFLite]
  │       ├── rootBundle.loadString(profile.labelsAssetPath)
  │       ├── _parseLabels() → List<String>
  │       ├── Vérification : outputShape.last == labels.length  ← GARDE
  │       └── Stockage dans Map<String, LoadedModel> _models
  │     Si un profil échoue → erreur loguée, chargement continue
  └── _activeId = defaultProfile.id (ou premier disponible si défaut absent)
```

**Résistance aux pannes** : si un profil échoue (asset manquant, mismatch de classes), il est simplement sauté. L'app reste fonctionnelle si au moins un modèle charge.

**`isReady`** : `bool get isReady => active != null`. Vérifié par la `HomePage` pour afficher une barre de progression pendant le chargement background, et par `DiagnosisRepositoryImpl` avant chaque inférence.

**Parsing des labels** : la méthode `_parseLabels(String raw)` détecte automatiquement le format :
- Si le contenu commence par `[` → JSON array (cas PlantVillage)
- Sinon → une ligne par label (cas cassava)

**`LoadedModel`** est le conteneur en mémoire : il regroupe `ModelProfile`, `Interpreter` TFLite et `List<String> labels`.

### 4.4 Prétraitement des images

**Fichier** : `lib/core/ml/image_preprocessor.dart`  
**Fonction principale** : `preprocessImage(String imagePath, {int inputSize, List<double> mean, List<double> std})`

Le prétraitement s'exécute dans un **isolate Dart** via `compute()` pour ne pas bloquer le thread UI :

```
preprocessImage(path, inputSize: 160)
  └── isolate _preprocessIsolate(_PreprocessArgs)
        ├── img.decodeImage(bytes)          ← décodage JPEG/PNG
        ├── img.copyResize(w: 160, h: 160)  ← redimensionnement
        ├── Pour chaque pixel :
        │     uint8Pixels[i] = (R, G, B)     ← brut uint8 [0-255]
        │     float32Input[i] = (pixel - mean) / std  ← normalisé float32
        └── Retourne PreprocessedImage{uint8Pixels, float32Input}
```

`PreprocessedImage` contient les deux représentations. `DiagnosisRepositoryImpl` choisit laquelle passer à TFLite selon le type du tenseur d'entrée (`TensorType.uint8` → `uint8Pixels.buffer`, sinon → `float32Input.buffer`).

### 4.5 Stratégie d'inférence multi-modèle

**Fichier** : `lib/features/diagnosis/data/repositories/diagnosis_repository_impl.dart`

Lors de chaque appel à `analyzeImage(imagePath)`, **tous les modèles chargés** sont exécutés en séquence. Ensuite l'algorithme sélectionne le meilleur résultat :

```
Priorité 1 : le candidat dont le label a une entrée dans diseases_knowledge.json
Priorité 2 (ex-aequo sur la connaissance) : la plus haute confiance
```

Ce mécanisme assure que le modèle cassava (spécialisé, plus fiable sur le manioc) prime sur PlantVillage pour les cultures communes, tout en permettant à PlantVillage de couvrir les cultures non gérées par cassava.

**Seuil de confiance** : `kConfidenceThreshold = 0.5`. En dessous, `DiagnosisResult.needsValidation` est mis à `true`.

**Race condition au démarrage** : si l'utilisateur lance un diagnostic très rapidement après le lancement de l'app (avant que le chargement background des modèles soit terminé), `DiagnosisRepositoryImpl` attend jusqu'à **6 secondes** via une boucle de polling (250 ms × 24 tentatives) avant de retourner une `ModelFailure`. Cela couvre la grande majorité des appareils sans bloquer l'UI.

**Softmax** : les logits bruts de chaque modèle passent par `_softmax()` avant sélection, ce qui normalise les sorties flottantes comme les sorties dé-quantifiées uint8.

---

## 5. Base de connaissances des maladies

### 5.1 Schéma JSON

**Fichier** : `assets/data/diseases_knowledge.json`  
**Contenu** : tableau de 45 objets (39 PlantVillage + 6 cassava)

Chaque entrée suit ce schéma :

```jsonc
{
  "model_label": "Tomato___Late_blight",  // ← doit correspondre EXACTEMENT au label TFLite
  "culture": "Tomate",
  "display_name": "Mildiou de la tomate",
  "description": "Description médicale complète en français.",
  "severity": "critique",                  // critique | grave | modéré | faible | aucune
  "is_healthy": false,
  "symptoms": [
    "Taches huileuses gris-vert sur les feuilles",
    "Brunissement rapide des tiges"
  ],
  "treatments": [
    {
      "method": "Traitement fongicide d'urgence",
      "steps": [
        "Appliquer de la bouillie bordelaise à 25 g/L",
        "Traiter tous les 7 jours par temps humide"
      ]
    }
  ],
  "products": [
    {
      "name": "Bouillie bordelaise",
      "dosage": "25 g/L",
      "priceXof": 6500,
      "application": "Pulvérisation foliaire"
    }
  ],
  "prevention": [
    "Utiliser des variétés résistantes",
    "Éviter l'arrosage sur les feuilles"
  ],
  "display_name_i18n": {
    "ee": "Tomati ƒe mildiou",
    "kab": "Tomati ƒe mildiou"
  },
  "description_i18n": {
    "ee": "Dɔmegblẽ sesẽ...",
    "kab": "Dɔmegblẽ sesẽ..."
  },
  "plain_explanation_i18n": {
    "fr": "Maladie très dangereuse. Peut tuer le champ en une semaine. Agissez immédiatement.",
    "ee": "Dɔ sesẽ ŋutɔ. Aɖu agble le kwasiɖa ɖeka me. Wɔ dɔ enumake.",
    "kab": "Dɔ sesẽ ŋutɔ. Aɖu agble le kwasiɖa ɖeka me. Wɔ dɔ enumake."
  }
}
```

**Règle critique** : `model_label` doit correspondre caractère par caractère au label émis par le modèle TFLite. Toute divergence (casse, underscore, espace) provoque un "diagnostic non documenté".

### 5.2 DiseaseInfo — entité domaine

**Fichier** : `lib/features/diagnosis/domain/entities/disease_info.dart`

`DiseaseInfo` est le miroir Dart de l'entrée JSON. Elle expose trois méthodes de localisation :

```dart
// Retourne le nom localisé, avec fallback sur displayName (français)
String localizedDisplayName(String langCode)

// Retourne la description localisée, avec fallback français
String localizedDescription(String langCode)

// Retourne l'explication courte pour TTS, avec fallback description
String localizedPlainExplanation(String langCode)
```

Elle expose également une méthode de copie immuable utilisée par le `TranslationService` pour injecter une traduction NLLB-200 à chaud :

```dart
// Retourne une copie avec la traduction NLLB injectée dans plainExplanationTranslations
DiseaseInfo withPlainExplanationOverride(String langCode, String text)
```

`DiseaseKnowledgeRepository.getDiseaseByLabel(String rawLabel)` charge le JSON au premier accès (lazy) et indexe les entrées par `model_label` dans une `Map<String, DiseaseInfo>` pour des lookups O(1).

---

## 6. Système multilingue & TTS

### 6.1 LanguageService

**Fichier** : `lib/core/services/language_service.dart`

```dart
enum AppLanguage { french, ewe, kabye }

@lazySingleton
class LanguageService extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.french;
  // Persisté dans Hive box 'language_prefs'
}
```

Codes de langue retournés par `languageCode` :
- `french` → `'fr'`
- `ewe` → `'ee'`
- `kabye` → `'kab'`

`LanguageService.t(key)` traduit les clés d'interface UI (ex. `'scan_plant'`, `'history'`). `translateTerm(term)` traduit les termes agricoles spécifiques (ex. `'feuille'`, `'traitement'`). Les tables de traduction sont embarquées dans le code source de `LanguageService`.

### 6.2 VoiceService

**Fichier** : `lib/core/services/voice_service.dart`

`VoiceService` encapsule deux packages :
- `flutter_tts` pour la synthèse vocale (TTS)
- `speech_to_text` pour la reconnaissance vocale (STT)

```dart
enum VoiceState { idle, listening, processing, speaking, error }

@lazySingleton
class VoiceService extends ChangeNotifier {
  // Configuration TTS : volume 1.0, pitch 1.0, speechRate 0.45 (lent)
  // Pour Éwé/Kabyè, le locale TTS est 'fr-TG' (pas de locale natale disponible)
}
```

**Traitement TTS pour les langues locales** : avant de passer le texte au moteur TTS, `_processTextForTts()` remplace les caractères spéciaux Éwé/Kabyè (ɛ, ŋ, ɔ, ɖ, ƒ) par leurs équivalents latins de base (`e`, `ng`, `o`, `d`, `f`). Cela évite que le moteur TTS les ignore ou les mispronounce.

**États du service** :
```
idle ──→ listening ──→ processing ──→ (callback externe)
idle ──→ speaking ──→ idle (completion handler)
tout état ──→ error (sur exception)
```

**Niveau audio simulé** : `_audioLevel` est animé périodiquement via un `Timer` pour donner un retour visuel à l'utilisateur pendant l'écoute (microphone animé). Le niveau est simulé car `speech_to_text` ne fournit pas de niveau audio en temps réel sur toutes les plateformes.

### 6.3 DiagnosisExplanationBuilder

**Fichier** : `lib/features/diagnosis/domain/entities/diagnosis_explanation.dart`

Le builder est un objet **sans état**, appellable depuis un provider ou un test unitaire :

```dart
class DiagnosisExplanationBuilder {
  DiagnosisExplanation build({
    required DiagnosisResult result,
    DiseaseInfo? info,
    required String langCode,
  })
}
```

Il produit deux textes :

| Champ | Usage | Contenu |
|---|---|---|
| `plainText` | Affiché en tête de résultat + lu automatiquement | Nom de la maladie + explication courte + gravité + 1re action |
| `detailedText` | Bouton "Écouter en détail" | Introduction + confiance % + description + symptômes + traitements + prévention |

**`_Dictionary`** encapsule le vocabulaire minimal nécessaire (12 termes) dans les trois langues. La classe interne `forLanguage(code)` retourne le dictionnaire approprié, avec français en fallback.

**Logique de construction du `plainText`** :
1. Commencer par `"Le diagnostic est [nom]."` (traduit)
2. Si `DiseaseInfo` disponible : ajouter l'explication courte localisée (`plain_explanation_i18n`)  
   → si langue `'ee'` et traduction NLLB disponible, utilise la traduction NLLB en priorité (via `withPlainExplanationOverride`)
3. Ajouter le niveau de gravité en mots simples (`critique` → `"très grave"`)
4. Ajouter la première étape du premier traitement
5. Si pas de `DiseaseInfo` : mentionner seulement le score de confiance

### 6.4 TranslationService — traduction NLLB-200

**Fichier** : `lib/core/services/translation_service.dart`

Ce service fournit des traductions automatiques en **éwé** via le modèle [facebook/nllb-200-distilled-600M](https://huggingface.co/facebook/nllb-200-distilled-600M) hébergé sur HuggingFace. Les traductions sont calculées côté serveur (Edge Function Supabase) et mises en cache localement dans Hive pour fonctionner hors ligne après la première connexion.

> **Kabyè non supporté** : NLLB-200 ne supporte pas le kabyè (`kab`). Les textes kabyè restent en français avec fallback.

#### Architecture

```
App (DiagnosisProvider)
    │
    ├─ Cache Hive 'nllb_translations' (Box<String>)
    │   clé : "${modelLabel}_${langCode}"
    │   → hit : traduction immédiate, pas d'appel réseau
    │
    └─ Miss : appel HTTP
         └─ SupabaseService.invokeBatchTranslate()
              └─ Supabase Edge Function /translate
                   └─ HuggingFace Inference API
                        └─ NLLB-200 distilled 600M
```

#### API publique

```dart
@lazySingleton
class TranslationService {
  // Vérifie si le service est prêt (Hive box ouverte)
  bool get isReady;

  // Initialise la Hive box — appelé dans _initBackground()
  Future<void> initialize();

  // Lecture cache uniquement — synchrone, pas de réseau
  String? getCached(String modelLabel, String langCode);

  // Traduit un texte français vers langCode — lit le cache d'abord
  Future<String?> translatePlainExplanation(
    String frenchText, {
    required String modelLabel,
    required String langCode,
  });

  // Pré-chauffe le cache pour toutes les maladies connues
  // Appelé au démarrage si Supabase est disponible
  Future<void> prefetchAll(List<DiseaseInfo> diseases);
}
```

#### Flux dans DiagnosisProvider

```
analyzeImage(imagePath)
  │
  ├─ ... (inférence ML) ...
  │
  ├─ Si langue == 'ee' ET cache hit :
  │    info = info.withPlainExplanationOverride('ee', cachedText)
  │
  ├─ notifyListeners()  ← UI s'affiche immédiatement
  │
  └─ Si langue == 'ee' ET pas de cache :
       _fetchNllbBackground(info)   ← fire-and-forget
         ├─ translationService.translatePlainExplanation(...)
         ├─ Si succès : info = info.withPlainExplanationOverride(...)
         ├─ Reconstruire explanation
         └─ notifyListeners()  ← UI se met à jour discrètement
```

#### Configuration Edge Function

La Edge Function `supabase/functions/translate/index.ts` nécessite un secret HuggingFace :

```bash
supabase secrets set HF_API_TOKEN=hf_votre_token_ici
supabase functions deploy translate
```

Elle accepte jusqu'à **20 textes par appel** en batch, et gère les erreurs 503 de cold start HuggingFace avec **3 tentatives automatiques** espacées de 10 s.

#### Codes de langue NLLB-200

| Code app | Code NLLB-200 | Supporté |
|---|---|---|
| `fr` | `fra_Latn` | ✅ |
| `ee` | `ewe_Latn` | ✅ |
| `kab` | — | ❌ (pas dans NLLB-200) |

---

## 7. Feature Diagnostic (bout en bout)

### 7.1 DiagnosisRepositoryImpl

**Fichier** : `lib/features/diagnosis/data/repositories/diagnosis_repository_impl.dart`

Implémente `DiagnosisRepository` (interface domaine). Reçoit `DiseaseKnowledgeRepository` par injection.

Flux complet de `analyzeImage(imagePath)` :

```
analyzeImage(imagePath)
 │
 ├─ Vérifier ModelManager.isReady
 │    └─ Si non : polling 250 ms × max 24 = 6 s
 │         └─ Toujours non prêt → ModelFailure (message utilisateur)
 │
 ├─ Pour chaque LoadedModel dans _modelsToRun() :
 │    ├─ preprocessImage(imagePath, inputSize: profile.inputSize, ...)
 │    ├─ _runInferenceFor(loaded, preprocessed)
 │    │    ├─ Allouer output buffer (uint8 ou float32 selon tenseur)
 │    │    ├─ interpreter.run(input, output)
 │    │    ├─ Dé-quantifier si uint8 → List<double> logits
 │    │    ├─ _softmax(logits) → probabilités
 │    │    └─ Retourner (rawLabel, confidence)
 │    └─ Comparer avec best : préférer connaissance > confiance
 │
 ├─ Si best == null → ModelFailure
 ├─ Si label contient 'background_without_leaves' → DiagnosisResult "Image inutilisable"
 ├─ Si DiseaseInfo trouvé → DiagnosisResult riche (description, traitements, produits)
 └─ Sinon → DiagnosisResult minimal (label formaté, invitation à consulter agronome)
```

### 7.2 DiagnosisProvider

**Fichier** : `lib/features/diagnosis/presentation/providers/diagnosis_provider.dart`

`DiagnosisProvider` est le centre de gravité de la feature. Il reçoit 8 dépendances par injection :

```dart
@injectable
class DiagnosisProvider extends ChangeNotifier {
  final DiagnosisRepository repository;
  final HistoryRepository historyRepository;
  final DiseaseKnowledgeRepository knowledgeRepository;
  final ValidationRepository validationRepository;
  final SyncService syncService;
  final VoiceService voiceService;           // ← TTS
  final LanguageService languageService;     // ← langue active
  final TranslationService translationService; // ← NLLB-200 traductions Éwé
}
```

**État exposé** :

| Propriété | Type | Description |
|---|---|---|
| `status` | `DiagnosisStatus` | `initial \| loading \| success \| error` |
| `result` | `DiagnosisResult?` | Résultat brut du modèle |
| `diseaseInfo` | `DiseaseInfo?` | Fiche enrichie de la maladie |
| `explanation` | `DiagnosisExplanation?` | Texte TTS plain + détaillé |
| `autoSpeakEnabled` | `bool` | Lecture automatique activée (défaut : true) |
| `validationRequested` | `bool` | L'utilisateur a déclenché le partage WhatsApp |

**Flux de `analyzeImage(imagePath)`** :
1. Statut → `loading`, notifier les listeners
2. Appel `repository.analyzeImage(imagePath)`
3. En cas de succès :
   a. Chercher `diseaseInfo` par `rawModelLabel` dans la base de connaissances
   b. Si langue `'ee'` et traduction en cache : appliquer `withPlainExplanationOverride`
   c. Construire `DiagnosisExplanation` via `DiagnosisExplanationBuilder`
   d. Persister le diagnostic dans Hive (`historyRepository.saveLocally`)
   e. Ajouter à la file de sync Supabase (`syncService`)
   f. Notifier les listeners (statut → `success`)
   g. Si `autoSpeakEnabled` : appeler `voiceService.speak(explanation.plainText)`
   h. Si langue `'ee'` et pas de cache NLLB : lancer `_fetchNllbBackground()` (fire-and-forget)

**API TTS exposée aux widgets** :

```dart
Future<void> speakPlain()    // relit le plainText
Future<void> speakDetailed() // lit le detailedText complet
Future<void> stopSpeaking()
void setAutoSpeakEnabled(bool enabled)
```

### 7.3 Pages et widgets

**Pages** :

| Fichier | Route | Rôle |
|---|---|---|
| `camera_page.dart` | `/camera` | Capture ou import de photo |
| `result_page.dart` | `/result` | Affichage du diagnostic |
| `history_page.dart` | `/history` | Historique des diagnostics |

**Widgets clés dans `result_widgets.dart`** :

- **`LoadingState`** : spinner animé avec 3 étapes de progression (prétraitement → analyse IA → recommandations)
- **`PlainExplanationCard`** : carte proéminente en tête de résultat affichant le `plainText`. Icône de haut-parleur animée (`graphic_eq`) quand TTS parle.
- **`VoiceControls`** : rangée de boutons "Écouter à nouveau" + "Écouter en détail", et switch de désactivation de la lecture automatique
- **`ValidationButton`** : bouton **toujours visible** (quelle que soit la confiance du diagnostic) invitant l'utilisateur à contacter un expert. Déclenche le partage WhatsApp via `share_plus`.
- **`SuccessState`** : widget composé assemblant `PlainExplanationCard`, fiches maladie, traitements, produits, `VoiceControls`, `ValidationButton`

#### Contact expert via WhatsApp (`share_plus`)

Lorsque l'utilisateur appuie sur **"Contacter un expert sur WhatsApp"**, la méthode `_shareWithExpert()` de `result_page.dart` est appelée :

```dart
static const _expertPhone = '+22891774563';

Future<void> _shareWithExpert(DiagnosisResult result, DiseaseInfo? info) async {
  await Share.shareXFiles(
    [XFile(result.imagePath)],           // photo prise par l'utilisateur
    subject: 'Diagnostic DoctAgri — ${info?.displayName ?? result.label}',
    text: _buildExpertMessage(result, info),  // message formaté WhatsApp
  );
}
```

`Share.shareXFiles` ouvre le **menu de partage natif Android/iOS** avec la photo et le texte pré-remplis. L'utilisateur sélectionne WhatsApp, et la conversation s'ouvre directement avec la photo et le message. Cela est la seule approche fiable pour envoyer **à la fois** une image et du texte vers WhatsApp (les deep links `wa.me/` ne supportent pas les pièces jointes).

Le message formaté inclut : numéro de l'expert, nom de la maladie, fiabilité %, gravité, culture, description (tronquée à 300 caractères), traitement conseillé et date.

---

## 8. Autres features

### Camera (`features/camera/`)

Utilise `camera` (prévisualisation live) et `image_picker` (import depuis galerie). Navigue vers `/result` en passant le chemin local de l'image.

### Home (`features/home/`)

Écran d'accueil avec : bouton scanner principal, dernière alerte météo, derniers diagnostics, raccourcis. Affiche `VoiceService.isListening` pour la saisie vocale.

**Indicateur de chargement ML** : pendant que les modèles TFLite se chargent en arrière-plan, la `HomePage` affiche une barre de progression fine sous le bouton scanner (`_buildModelLoadingBar()`). Elle disparaît automatiquement quand `ModelManager.isReady` passe à `true`.

### Advice (`features/advice/`)

Conseils culturaux issus de `crop_tips.json`. Organisés par culture, accessibles depuis l'accueil.

### Weather (`features/weather/`)

Intégration météo locale (API externe). Affiche température, précipitations, alertes pertinentes pour l'agriculture.

### Payment (`features/payment/`)

Flux de paiement Mobile Money pour soumettre un diagnostic à un expert agronomique.

**Moyens de paiement supportés (Togo)** :

| Enum | Nom affiché | Réseau | Couleur marque |
|---|---|---|---|
| `PaymentMethod.mixxByYas` | Mixx By Yas | Togocel / Yas (anciennement Tmoney) | `#6B21A8` (violet) |
| `PaymentMethod.moovMoney` | Moov Money (Flooz) | Moov Africa Togo | `#0056B3` (bleu) |

La sélection de la méthode est représentée par des tuiles animées (`AnimatedContainer`, 180 ms) affichant l'icône avec la couleur de l'opérateur et un sous-titre descriptif. La méthode `mixxByYas` est sélectionnée par défaut.

**Entités** : `Order`, `PaymentMethod`  
**Pages** : `CheckoutPage`, `PaymentProcessingPage`, `PaymentSuccessPage`

---

## 9. Services transverses

### SyncService & SyncQueue

**Fichiers** : `lib/core/services/sync_service.dart`, `sync_queue.dart`

Implémentation de la stratégie **offline-first** :

```
Diagnostic créé
    └─→ HistoryRepository.saveLocally()  [Hive]
    └─→ SyncQueue.enqueue(diagnosisId)   [Hive box 'syncBox']

Connectivité restaurée (event connectivity_plus)
    └─→ SyncService.processQueue()
          ├─ Pour chaque item en attente (max 5 retries) :
          │    ├─ SupabaseService.uploadDiagnosis()
          │    └─ Marquer item comme synced / incrémenter retryCount
          └─ Timeout global : 30 secondes
```

Un `Completer<void> _syncLock` évite les syncs simultanées.

### SupabaseService

**Fichier** : `lib/core/services/supabase_service.dart`

Wrapper sur `supabase_flutter`. Expose :
- Auth (sign in, sign up, sign out)
- Upload image vers Supabase Storage
- Insert/update diagnostics dans la table `diagnoses`
- Appel aux Edge Functions (génération URL signée, notification expert)
- **`invokeBatchTranslate()`** — appel à l'Edge Function de traduction NLLB-200 :

```dart
Future<List<String>?> invokeBatchTranslate({
  required List<String> texts,
  required String targetLang,      // ex. 'ewe_Latn'
  String sourceLang = 'fra_Latn',
})
```

### TranslationService

Voir [§ 6.4 TranslationService — traduction NLLB-200](#64-translationservice--traduction-nllb-200).

### FeatureFlagService

**Fichier** : `lib/core/services/feature_flag_service.dart`

Flags booléens simples pour activer/désactiver des fonctionnalités en runtime (ex. `weatherEnabled`, `paymentEnabled`). Permet un déploiement progressif sans recompilation.

---

## 10. Navigation (go_router)

**Fichier** : `lib/core/router/app_router.dart`

```
/splash                    ← SplashScreen (init + chargement modèles)
/                          ← HomePage  ┐
/history                   ← HistoryPage ┘ ← ShellRoute (BottomNavBar)
/camera                    ← CameraPage (navigation modale, hors shell)
/result                    ← ResultPage (extra: imagePath String)
/advice                    ← CropAdviceListPage
/advice/:cropId            ← CropDetailPage
/checkout                  ← CheckoutPage (extra: TreatmentProduct)
/payment/processing        ← PaymentProcessingPage (extra: Order)
/payment/success           ← PaymentSuccessPage
```

Les routes `/camera` et `/result` utilisent `parentNavigatorKey: _rootNavigatorKey` pour s'afficher au-dessus de la `BottomNavBar` (plein écran).

---

## 11. Injection de dépendances (injectable + GetIt)

**Pattern** : annotations `@injectable`, `@lazySingleton`, `@singleton` sur les classes. `build_runner` génère `injection_container.config.dart`.

```
configureDependencies()           ← appelé dans main()
    └─ sl.init()
         ├─ Services (lazySingleton) : LanguageService, VoiceService,
         │   SupabaseService, TranslationService, SyncQueue,
         │   SyncService, FeatureFlagService
         ├─ Hive Boxes (async factory) : diagnosisBox, syncBox, validationBox
         ├─ Repositories (lazySingleton) : DiseaseKnowledgeRepository,
         │   HistoryRepository, DiagnosisRepository, ValidationRepository
         └─ Providers (factory) : DiagnosisProvider, HistoryProvider…
```

> **Important** : `DiagnosisProvider` est enregistré en `factory` (nouvelle instance à chaque navigation) car son état doit être réinitialisé à chaque diagnostic. Les services (`VoiceService`, `LanguageService`, `TranslationService`) sont en `lazySingleton` car ils maintiennent un état global ou un cache.

**Régénération après modification** :

```bash
dart run build_runner build --delete-conflicting-outputs
```

À exécuter chaque fois qu'une classe annotée `@injectable` est ajoutée ou modifiée.

---

## 12. Backend Supabase

### Tables principales

| Table | Colonnes clés | RLS |
|---|---|---|
| `diagnoses` | `id`, `user_id`, `image_url`, `label`, `confidence`, `raw_model_label`, `created_at` | Lecture/écriture propriétaire uniquement |
| `validation_requests` | `diagnosis_id`, `expert_id`, `status`, `notes` | Expert peut lire les siennes |
| `users` | Géré par Supabase Auth | — |

### Edge Functions

| Fonction | Déclencheur | Rôle |
|---|---|---|
| `translate` | HTTP POST | Traduction NLLB-200 via HuggingFace (batch, cache, retry cold start) |
| `generate-signed-url` | HTTP POST | URL signée temporaire pour accès image |
| `notify-expert` | HTTP POST | Email/push notification à l'expert assigné |
| `export-user-data` | HTTP GET | Export RGPD des données utilisateur (JSON) |
| `delete-user-data` | HTTP DELETE | Suppression RGPD complète |

#### Edge Function `translate` — détails

**Fichier** : `supabase/functions/translate/index.ts`  
**Corps de la requête** :
```json
{ "texts": ["..."], "targetLang": "ewe_Latn", "sourceLang": "fra_Latn" }
```
**Réponse** :
```json
{ "translations": ["..."], "model": "facebook/nllb-200-distilled-600M" }
```

- Maximum **20 textes** par appel
- **3 tentatives** automatiques sur HTTP 503 (cold start HuggingFace), délai 10 s
- Headers CORS inclus pour les appels depuis l'app Flutter
- Nécessite le secret Supabase `HF_API_TOKEN`

### Migrations SQL

Situées dans `supabase/migrations/`, versionnées par timestamp. Inclure toute modification de schéma dans une nouvelle migration, jamais modifier les existantes.

---

## 13. Pipeline Python ML (hors app)

**Répertoire** : `ml/pipeline/`

6 étapes enchaînées par le `Makefile` :

| Script | Étape | Description |
|---|---|---|
| `01_export_savedmodel.py` | Export | Keras → SavedModel TensorFlow |
| `02_build_representative_dataset.py` | Dataset | Constitution du dataset de calibration pour quantification |
| `03_quantize_int8.py` | Quantification | SavedModel → TFLite INT8 avec calibration |
| `04_validate_accuracy.py` | Validation | Mesure de la perte de précision post-quantification |
| `05_benchmark_device.py` | Benchmark | Simulation latence device mobile |
| `06_package_artifact.py` | Package | Copie vers `assets/models/`, calcul SHA256, mise à jour `registry.json` |

**Prérequis Python** :
- Python **3.12** (TensorFlow n'est pas disponible sur 3.14+)
- `tensorflow`, `numpy`, `pillow`

**Génération des entrées de connaissance PlantVillage** :

```bash
PYTHONIOENCODING=utf-8 py -3.12 ml/build_plantvillage_knowledge.py
```

Ce script génère les 39 entrées PlantVillage et les fusionne dans `assets/data/diseases_knowledge.json`.

---

## 14. Packages Dart isolés

Le monorepo utilise **Melos** (`melos.yaml`) pour gérer 10 packages isolés sous `packages/`. Chaque package a son propre `pubspec.yaml`.

| Package | Rôle |
|---|---|
| `doctagri_auth` | Logique d'authentification |
| `doctagri_core` | Types partagés, failures, extensions |
| `doctagri_design_system` | Atoms, molécules, tokens design (couleurs, typo) |
| `doctagri_diagnosis` | Entités et use cases du diagnostic (réutilisable) |
| `doctagri_history` | Persistance et récupération de l'historique |
| `doctagri_knowledge` | Accès à la base de connaissances des maladies |
| `doctagri_ml_engine` | Abstraction du moteur TFLite (portable) |
| `doctagri_sync` | Logique de synchronisation offline-first |
| `doctagri_telemetry` | Événements analytics + service telemetrie |
| `doctagri_validation` | Workflow de validation expert |

---

## 15. Comment ajouter un nouveau modèle TFLite

### Étape 1 — Placer les fichiers

```
assets/models/<id>/
├── model.tflite        ← le modèle quantifié
└── class_names.json    ← JSON array de labels  (ou labels.txt)
```

Déclarer le dossier dans `pubspec.yaml` :

```yaml
flutter:
  assets:
    - assets/models/<id>/
```

### Étape 2 — Déclarer le profil

Dans `lib/core/ml/model_manager.dart`, ajouter à `ModelCatalog` :

```dart
static const ModelProfile monNouveauModele = ModelProfile(
  id: 'mon_modele',
  displayName: 'Mon modèle (description)',
  assetPath: 'assets/models/mon_modele/model.tflite',
  labelsAssetPath: 'assets/models/mon_modele/class_names.json',
  inputSize: 224,          // selon le modèle
  cultures: ['MaCulture'],
);

// Ajouter à la liste :
static const List<ModelProfile> all = [plantVillage, cassava, monNouveauModele];
```

### Étape 3 — Ajouter les entrées de connaissance

Pour chaque classe du nouveau modèle, ajouter une entrée dans `assets/data/diseases_knowledge.json` (voir [schéma §5.1](#51-schéma-json)).

### Étape 4 — Mettre à jour registry.json

Ajouter l'entrée dans `assets/models/registry.json` pour la traçabilité :

```json
{
  "id": "mon_modele",
  "version": "1.0",
  "num_classes": 10,
  "sha256": "...",
  "source": "...",
  "released_at": "2026-06-01T00:00:00Z"
}
```

**C'est tout.** `ModelManager.initialize()` chargera automatiquement le nouveau modèle au démarrage (en parallèle des autres), et `DiagnosisRepositoryImpl` l'incluera dans la stratégie multi-modèle.

### Règle de validation

Au chargement, `ModelManager._loadProfile` vérifie que `outputShape.last == labels.length`. Si le modèle produit N classes mais que le fichier de labels n'en contient pas exactement N, le chargement échoue avec un `StateError` clair dans les logs.

---

## 16. Comment ajouter une entrée de maladie

Si un modèle existant produit un label non documenté (affiché comme "non documenté dans notre base"), ajouter l'entrée suivante dans `assets/data/diseases_knowledge.json` :

```jsonc
{
  "model_label": "Tomato___Spider_mites Two-spotted_spider_mite",
  // ↑ Copier exactement depuis class_names.json ou labels.txt
  "culture": "Tomate",
  "display_name": "Acariens à deux points (Tomate)",
  "description": "Infestation d'acariens Tetranychus urticae...",
  "severity": "modéré",
  "is_healthy": false,
  "symptoms": ["Petits points blancs/jaunes sur les feuilles", "Toiles fines sous les feuilles"],
  "treatments": [
    {
      "method": "Traitement acaricide",
      "steps": ["Pulvériser de l'huile de neem à 20 mL/L", "Répéter après 7 jours"]
    }
  ],
  "products": [
    {"name": "Huile de neem", "dosage": "20 mL/L", "priceXof": 3500, "application": "Pulvérisation"}
  ],
  "prevention": ["Éviter les excès d'azote", "Surveiller l'envers des feuilles"],
  "display_name_i18n": {"ee": "Tomati ƒe akadisi", "kab": "Tomati ƒe akadisi"},
  "description_i18n": {"ee": "...", "kab": "..."},
  "plain_explanation_i18n": {
    "fr": "Des acariens attaquent vos plants de tomate. Traitez rapidement à l'huile de neem.",
    "ee": "Akadisiwo le ɖo tomati ƒe hawo. Wɔ dɔ ko enumake.",
    "kab": "Akadisiwo le ɖo tomati ƒe hawo. Wɔ dɔ ko enumake."
  }
}
```

**Vérifications** :
1. `model_label` → copier-coller depuis le fichier de labels, aucune correction de casse
2. `plain_explanation_i18n.fr` → 1-2 phrases courtes, ton direct, pas de jargon
3. `plain_explanation_i18n.ee` → une version provisoire suffit ; NLLB-200 calculera automatiquement une traduction au prochain démarrage avec réseau et mettra à jour le cache Hive
4. Les caractères spéciaux (ɛ, ŋ, ɔ, ɖ, ƒ) seront translittérés automatiquement par `VoiceService._processTextForTts()` avant la lecture TTS

> Les traductions Éwé/Kabyè actuelles sont fonctionnelles mais doivent être **relues par un locuteur natif** avant déploiement en production.

---

## 17. Déploiement et limitations connues

### Build de production

La commande de build utilise `flutter build` (et non Gradle directement) pour que les constantes Dart `--dart-define` soient correctement transmises à la compilation :

```bash
# Android — via build_apk.bat (Windows)
flutter build apk --release ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

# iOS
flutter build ipa --release ^
  --dart-define=SUPABASE_URL=$SUPABASE_URL ^
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### Déploiement Supabase Edge Functions

```bash
# Déployer la fonction de traduction NLLB-200
supabase functions deploy translate

# Configurer le token HuggingFace (requis pour translate)
supabase secrets set HF_API_TOKEN=hf_votre_token_ici
```

Le token HuggingFace est disponible sur [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens). Un compte gratuit suffit pour l'Inference API.

### Stratégie de démarrage (startup optimization)

L'app est conçue pour afficher l'écran d'accueil en **< 400 ms** sur la grande majorité des appareils :

```
main()
  ├── CHEMIN CRITIQUE (bloquant) :
  │     ├── Hive.initFlutter()
  │     ├── Hive.registerAdapter(DiagnosisResultAdapter)
  │     ├── configureDependencies()
  │     └── languageService.initialize()    ← requis pour les textes UI
  │
  ├── runApp()  ←  UI visible ici (~300 ms depuis le lancement)
  │
  └── _initBackground()  ← arrière-plan, ne bloque plus l'UI
        ├── Future.wait([               ← en parallèle :
        │     voiceService.initialize(),   STT ~1 s sur Android
        │     knowledgeRepo.initialize(),  lecture JSON assets
        │     ModelManager.initialize(),   chargement TFLite parallèle
        │   ])
        ├── supabaseService.initialize()   réseau, après les assets
        ├── syncService.startListening()
        └── translationService.initialize() + prefetchAll()
```

La `HomePage` affiche une barre de progression pendant le chargement ML et se met à jour automatiquement quand `ModelManager.isReady` passe à `true`.

### Limitations connues

| Limitation | Impact | Contournement |
|---|---|---|
| TTS Éwé/Kabyè non natif | Prononciation approximative | Translittération automatique des caractères spéciaux + locale `fr-TG` |
| `injection_container.config.dart` régénéré manuellement | Risque de désynchro DI | Toujours exécuter `build_runner` après modification d'une classe `@injectable` |
| STT Éwé/Kabyè non disponible | Saisie vocale en français seulement | Locale `fr_TG` utilisée pour les deux langues locales |
| Modèle cassava — 6 classes seulement | Ne couvre pas toutes les maladies du manioc | Compensé par PlantVillage (couverture générale) dans la stratégie multi-modèle |
| Traductions locales non vérifiées par des natifs | Qualité variable des explications vocales | Revue natif requise avant production |
| Python 3.12 requis pour TensorFlow | Pipeline ML ne fonctionne pas sur Python 3.14+ | Utiliser explicitement `py -3.12` sur Windows |
| NLLB-200 ne supporte pas le kabyè | Textes kabyè restent en français | Surveiller les futures versions du modèle |
| Traductions NLLB nécessitent une connexion au premier accès | Cache vide au premier lancement hors réseau | `prefetchAll()` exécuté dès le démarrage si réseau disponible ; les diagnostics offline n'ont pas de traduction NLLB mais affichent le texte français |
| Partage WhatsApp via menu système | L'utilisateur doit sélectionner WhatsApp manuellement | Numéro expert affiché dans le texte pré-rempli pour faciliter l'envoi |

### Variables d'environnement

Voir `.env.example` à la racine du projet.

| Variable | Usage | Scope |
|---|---|---|
| `SUPABASE_URL` | URL du projet Supabase | `--dart-define` au build |
| `SUPABASE_ANON_KEY` | Clé publique Supabase | `--dart-define` au build |
| `HF_API_TOKEN` | Token HuggingFace pour NLLB-200 | Secret Supabase (jamais dans l'APK) |

Les clés Supabase ne doivent jamais être commitées en clair dans le dépôt.

### Tests

```bash
flutter test                    # tests unitaires
flutter test integration_test/  # tests d'intégration (émulateur requis)
```

Le dossier `supabase/load_test/` contient un script k6 (`k6_diagnoses.js`) pour les tests de charge du backend.

### Runbooks opérationnels

Voir `docs/runbook/` :
- `incident-response.md` — procédure en cas d'incident production
- `rollback-procedures.md` — retour arrière modèle ou app
- `on-call-rotation.md` — organisation de l'astreinte
- `post-mortem-template.md` — template post-mortem

---

*Documentation mise à jour le 2026-05-03. Pour toute question, contacter l'équipe DoctAgri.*
