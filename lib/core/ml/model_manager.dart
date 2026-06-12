import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'culture_detector.dart';
import 'image_preprocessor.dart';

/// Applique une calibration de température puis softmax sur des logits.
///
/// Mathématiquement : `softmax(logits / temperature)`.
///
/// La calibration de température est une post-correction simple qui
/// aplatit (T > 1) ou pique (T < 1) la distribution des probabilités
/// sans changer le classement des classes (argmax invariant). C'est la
/// méthode standard pour corriger les modèles sur-confiants, typique
/// des INT8 quantifiés.
///
/// Pour calibrer T : minimiser la NLL sur un set de validation étiqueté.
///
/// - `T = 1.0` (défaut) : softmax standard, comportement inchangé.
/// - `T > 1.0` : top-1 baisse, queues remontent.
/// - `T < 1.0` : top-1 monte, queues s'effondrent.
///
/// L'implémentation utilise le « max subtract trick » pour la stabilité
/// numérique (évite les overflow d'exp pour les grands logits).
///
/// Retourne une liste vide pour une entrée vide.
List<double> calibratedSoftmax(
  List<double> logits, {
  double temperature = 1.0,
}) {
  if (logits.isEmpty) return const [];
  assert(temperature > 0, 'temperature doit être strictement positif');

  // Pas d'allocation si T = 1.0 (cas par défaut, hot path).
  final Iterable<double> scaled =
      temperature == 1.0 ? logits : logits.map((l) => l / temperature);

  final maxLogit = scaled.reduce((a, b) => a > b ? a : b);
  final exps = scaled.map((l) => math.exp(l - maxLogit)).toList(growable: false);
  final sumExps = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExps).toList(growable: false);
}

/// Recalibre une distribution de probabilités **déjà normalisée** (sortie d'un
/// modèle qui inclut sa propre couche softmax) avec une température, SANS la
/// ré-écraser par un second softmax.
///
/// La plupart des modèles TFLite quantifiés de ce projet exportent une couche
/// softmax finale : leur sortie est déjà une distribution de probabilités
/// (valeurs dans [0, 1], somme ≈ 1). Leur appliquer [calibratedSoftmax]
/// reviendrait à faire un **double softmax**, ce qui aplatit dramatiquement la
/// confiance — une prédiction réelle à 99 % tombe à ~35 % sur 6 classes et
/// ~7 % sur 39 classes. Cette fonction est la voie correcte pour ces modèles.
///
/// Mathématiquement : `p_i^(1/T) / Σ_j p_j^(1/T)`, soit `softmax(log(p) / T)`.
/// Préserve l'argmax pour tout `T > 0`.
///
/// - `T = 1.0` (défaut) : simple renormalisation. La sortie déquantifiée somme
///   rarement EXACTEMENT à 1 (ex. 255/256), donc on renormalise toujours.
/// - `T > 1.0` : aplatit la distribution. `T < 1.0` : la pique.
///
/// Retourne une liste vide pour une entrée vide.
List<double> temperatureScaleProbabilities(
  List<double> probs, {
  double temperature = 1.0,
}) {
  if (probs.isEmpty) return const [];
  assert(temperature > 0, 'temperature doit être strictement positif');

  if (temperature == 1.0) {
    final sum = probs.fold<double>(0.0, (a, b) => a + b);
    if (sum <= 0) {
      return List<double>.filled(probs.length, 1.0 / probs.length);
    }
    return probs.map((p) => p / sum).toList(growable: false);
  }

  // p^(1/T) renormalisé. On traite p <= 0 (bruit de quantification) comme 0
  // pour éviter NaN via pow.
  final invT = 1.0 / temperature;
  final scaled = probs
      .map((p) => p <= 0 ? 0.0 : math.pow(p, invT).toDouble())
      .toList(growable: false);
  final sum = scaled.fold<double>(0.0, (a, b) => a + b);
  if (sum <= 0) {
    return List<double>.filled(probs.length, 1.0 / probs.length);
  }
  return scaled.map((s) => s / sum).toList(growable: false);
}

/// Profil d'un modèle de diagnostic (taille d'entrée, labels, normalisation).
///
/// Chaque modèle TFLite peut avoir des contraintes différentes (taille
/// d'image, espace de labels, mean/std). Le profil les regroupe dans une
/// structure unique pour permettre le chargement multi-modèle.
class ModelProfile {
  final String id;
  final String displayName;
  final String assetPath;
  final String labelsAssetPath;
  final int inputSize;
  final List<double> mean;
  final List<double> std;
  final List<String> cultures;

  /// Température de calibration. Selon [outputsProbabilities], elle est
  /// appliquée soit sur les logits via [calibratedSoftmax]
  /// (`softmax(logits / T)`), soit sur les probabilités via
  /// [temperatureScaleProbabilities] (`p^(1/T)` renormalisé). Dans les deux
  /// cas l'argmax est préservé.
  ///
  /// - `T = 1.0` (défaut) → aucune transformation, comportement
  ///   historique préservé.
  /// - `T > 1.0` → aplatit la distribution. À utiliser pour des
  ///   modèles sur-confiants (typique des INT8 quantifiés). Une
  ///   confiance de 0.95 devient ~0.75–0.85 selon T.
  /// - `T < 1.0` → pique la distribution. Rare. Utile uniquement si
  ///   le modèle est sous-confiant, ce qui est inhabituel.
  ///
  /// **Calibration correcte** : trouver T qui minimise la NLL (negative
  /// log-likelihood) sur un set de validation étiqueté. Sans données,
  /// laisser à 1.0 plutôt que deviner — une mauvaise T peut empirer
  /// la calibration.
  final double temperature;

  /// La sortie brute du modèle est-elle déjà une distribution de probabilités
  /// (couche softmax incluse dans le `.tflite`) plutôt que des logits ?
  ///
  /// - `true`  → on applique [temperatureScaleProbabilities] (pas de softmax).
  /// - `false` → on applique [calibratedSoftmax] (le modèle sort des logits).
  /// - `null` (défaut) → auto-détection à l'inférence (somme ≈ 1 et valeurs
  ///   ≥ 0 ⇒ probabilités). Le filet de sécurité qui empêche le bug de
  ///   double softmax de réapparaître si un nouveau modèle est ajouté sans
  ///   renseigner ce champ.
  ///
  /// Les deux modèles embarqués (cassava, plantvillage) exportent un softmax
  /// final : leur sortie déquantifiée somme à ~1 (scale 1/256, zero 0).
  final bool? outputsProbabilities;

  const ModelProfile({
    required this.id,
    required this.displayName,
    required this.assetPath,
    required this.labelsAssetPath,
    this.inputSize = 224,
    this.mean = kImageNetMean,
    this.std = kImageNetStd,
    this.cultures = const [],
    this.temperature = 1.0,
    this.outputsProbabilities,
  }) : assert(temperature > 0, 'temperature doit être strictement positif');
}

/// Catalogue des modèles embarqués dans l'app.
///
/// Pour ajouter un nouveau modèle :
/// 1. Mettre les fichiers `.tflite` et labels dans `assets/models/<id>/`
/// 2. Déclarer un `ModelProfile` ici
/// 3. Ajouter les entrées de connaissances correspondantes dans
///    `assets/data/diseases_knowledge.json`
class ModelCatalog {
  static const ModelProfile cassava = ModelProfile(
    id: 'cassava',
    displayName: 'Manioc (spécialisé)',
    assetPath: 'assets/models/model.tflite',
    labelsAssetPath: 'assets/models/labels.txt',
    inputSize: 224,
    cultures: ['Manioc'],
    outputsProbabilities: true,
  );

  static const ModelProfile plantVillage = ModelProfile(
    id: 'plantvillage',
    displayName: 'Multi-cultures (général)',
    assetPath: 'assets/models/plantvillage/model_int8.tflite',
    labelsAssetPath: 'assets/models/plantvillage/class_names.json',
    inputSize: 160,
    cultures: [
      'Tomate',
      'Maïs',
      'Pomme de terre',
      'Piment',
      'Pomme',
      'Cerise',
      'Vigne',
      'Orange',
      'Pêche',
      'Fraise',
      'Soja',
      'Courge',
      'Framboise',
      'Myrtille',
    ],
    outputsProbabilities: true,
  );

  /// Profil par défaut. Le modèle multi-cultures couvre plus de cas.
  static const ModelProfile defaultProfile = plantVillage;

  static const List<ModelProfile> all = [plantVillage, cassava];

  static ModelProfile? findById(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Conteneur d'un modèle TFLite chargé en mémoire avec son profil.
class LoadedModel {
  final ModelProfile profile;
  final Interpreter interpreter;
  final List<String> labels;

  /// Préfixes anglais des labels du modèle (ex. {'Tomato', 'Apple'} pour
  /// plantvillage, {'Cassava'} pour cassava). Utilisé par le
  /// [CultureDetector] pour décider si un modèle est pertinent pour
  /// une image dont la culture est détectée. Calculé une fois au
  /// chargement à partir de [labels].
  final Set<String> domainPrefixes;

  LoadedModel({
    required this.profile,
    required this.interpreter,
    required this.labels,
  }) : domainPrefixes = _computeDomainPrefixes(labels);

  void dispose() => interpreter.close();

  static Set<String> _computeDomainPrefixes(List<String> labels) {
    final prefixes = <String>{};
    for (final label in labels) {
      final p = extractCultureFromLabel(label);
      if (p != null) prefixes.add(p);
    }
    return prefixes;
  }
}

/// Gestionnaire central des modèles ML.
///
/// Stocke plusieurs modèles chargés simultanément et permet d'en
/// sélectionner un actif. Maintient la compatibilité ascendante avec
/// l'ancienne API monolithique (`interpreter`, `labels`).
class ModelManager {
  static final ModelManager instance = ModelManager._();
  ModelManager._();

  final Map<String, LoadedModel> _models = {};
  String? _activeId;
  String? _initializationError;

  Completer<bool>? _initCompleter;

  bool get isReady => active != null;
  String? get error => _initializationError;
  List<ModelProfile> get availableProfiles =>
      _models.values.map((m) => m.profile).toList();

  /// Modèle actuellement actif (utilisé par défaut pour l'inférence).
  LoadedModel? get active => _activeId == null ? null : _models[_activeId];

  /// Initialise tous les profils déclarés dans [ModelCatalog]. Le profil
  /// par défaut devient actif s'il a chargé avec succès, sinon le premier
  /// disponible.
  Future<bool> initialize() async {
    if (isReady) return true;

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<bool>();
    _initializationError = null;

    final List<String> errors = [];

    // Charger tous les modèles en parallèle (plus rapide que séquentiel)
    await Future.wait(
      ModelCatalog.all.map((profile) async {
        try {
          await _loadProfile(profile);
          if (kDebugMode) debugPrint('✅ Modèle "${profile.id}" chargé');
        } catch (e) {
          errors.add('${profile.id}: $e');
          if (kDebugMode) debugPrint('⚠️ Modèle "${profile.id}" non chargé: $e');
        }
      }),
    );

    if (_models.isEmpty) {
      _initializationError = errors.join(' | ');
      _initCompleter!.complete(false);
      return false;
    }

    _activeId = _models.containsKey(ModelCatalog.defaultProfile.id)
        ? ModelCatalog.defaultProfile.id
        : _models.keys.first;

    _initCompleter!.complete(true);
    return true;
  }

  Future<void> _loadProfile(ModelProfile profile) async {
    final options = InterpreterOptions()..threads = 4;
    final interpreter = await Interpreter.fromAsset(
      profile.assetPath,
      options: options,
    );

    final labelData = await rootBundle.loadString(profile.labelsAssetPath);
    final labels = _parseLabels(labelData);

    final outputShape = interpreter.getOutputTensor(0).shape;
    final numClasses = outputShape.last;
    if (numClasses != labels.length) {
      interpreter.close();
      throw StateError(
        'Mismatch: modèle ${profile.id} produit $numClasses classes mais '
        '${labels.length} labels chargés.',
      );
    }

    _models[profile.id] = LoadedModel(
      profile: profile,
      interpreter: interpreter,
      labels: labels,
    );
  }

  /// Parse les labels depuis un fichier `.txt` (un par ligne) ou un JSON
  /// array de strings (`["foo","bar"]`).
  static List<String> _parseLabels(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    }
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Bascule le modèle actif. Retourne false si l'identifiant est inconnu.
  bool setActive(String id) {
    if (!_models.containsKey(id)) return false;
    _activeId = id;
    if (kDebugMode) debugPrint('🔁 Modèle actif: $id');
    return true;
  }

  /// Retourne le modèle correspondant à un identifiant, ou null.
  LoadedModel? getById(String id) => _models[id];

  // ── Compatibilité ascendante ──

  Interpreter get interpreter {
    final a = active;
    if (a == null) {
      throw StateError('ModelManager non initialisé. Appelez initialize().');
    }
    return a.interpreter;
  }

  List<String> get labels {
    final a = active;
    if (a == null) {
      throw StateError('ModelManager non initialisé. Appelez initialize().');
    }
    return List.unmodifiable(a.labels);
  }

  ModelProfile get activeProfile {
    final a = active;
    if (a == null) {
      throw StateError('ModelManager non initialisé. Appelez initialize().');
    }
    return a.profile;
  }

  void dispose() {
    for (final m in _models.values) {
      m.dispose();
    }
    _models.clear();
    _activeId = null;
    _initCompleter = null;
    if (kDebugMode) debugPrint('🗑️ ModelManager dispose');
  }

  Future<bool> reload() async {
    dispose();
    return initialize();
  }
}
