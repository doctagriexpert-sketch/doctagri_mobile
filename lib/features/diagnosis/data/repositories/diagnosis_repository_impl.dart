import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/ml/culture_detector.dart';
import '../../../../core/ml/model_manager.dart';
import '../../../../core/ml/image_preprocessor.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../domain/entities/disease_info.dart';
import '../../domain/repositories/diagnosis_repository.dart';
import '../../domain/repositories/disease_knowledge_repository.dart';

const double kConfidenceThreshold = 0.5;

/// Marge minimale top-1 − top-2 (en probabilité softmax) en dessous de
/// laquelle on considère le diagnostic comme ambigu. Au-dessus du seuil
/// de confiance brut [kConfidenceThreshold], un top-1 à 60% face à un
/// top-2 à 55% reste statistiquement fragile → on demande quand même
/// une validation humaine.
const double kAmbiguityMargin = 0.1;

/// Règle pure de décision de validation, extraite pour pouvoir être
/// testée sans avoir à monter tout le pipeline d'inférence.
///
/// Une validation humaine est demandée si :
///   - la confiance du top-1 est en dessous de [kConfidenceThreshold], OU
///   - la marge top-1 − top-2 est en dessous de [kAmbiguityMargin]
///     (le modèle hésite entre deux classes proches).
bool shouldRequestValidation({
  required double confidence,
  required double margin,
}) =>
    confidence < kConfidenceThreshold || margin < kAmbiguityMargin;

/// Seuil de probabilité au-dessus duquel on rejette l'image comme
/// inexploitable (« pas de feuille bien visible »), même si la classe
/// `Background_without_leaves` n'est pas le top-1.
///
/// Exemple typique attrapé par cette règle : modèle PlantVillage
/// retourne `Tomato___Early_blight` à 0.35 (top-1) et
/// `Background_without_leaves` à 0.30 (top-2) — sans ce seuil on
/// diagnostiquerait un mildiou alors que la photo est largement
/// hors-sujet.
const double kBackgroundRejectThreshold = 0.25;

/// Règle pure : faut-il rejeter l'image comme background ?
bool shouldRejectAsBackground(double backgroundProb) =>
    backgroundProb > kBackgroundRejectThreshold;

/// Heuristique : la sortie brute d'un modèle ressemble-t-elle à une
/// distribution de probabilités (toutes valeurs ≥ ~0 et somme ≈ 1) plutôt
/// qu'à des logits ?
///
/// Utilisé en repli quand [ModelProfile.outputsProbabilities] est `null`
/// (profil n'ayant pas déclaré explicitement le type de sortie). Empêche le
/// bug de double softmax de réapparaître silencieusement si un nouveau modèle
/// à softmax intégré est ajouté sans configuration.
///
/// La tolérance sur la somme (0.9–1.1) absorbe le bruit de quantification
/// (une sortie uint8 somme typiquement à 255/256 ≈ 0.996).
bool looksLikeProbabilities(List<double> values) {
  if (values.isEmpty) return false;
  double sum = 0.0;
  for (final v in values) {
    if (v < -1e-3) return false;
    sum += v;
  }
  return sum > 0.9 && sum < 1.1;
}

/// Reconnait le label `Background_without_leaves` de PlantVillage avec
/// une tolérance aux variantes de casse / séparateurs.
bool isBackgroundLabel(String label) {
  final lower = label.toLowerCase();
  return lower.contains('background') &&
      lower.contains('without') &&
      lower.contains('leaves');
}

@LazySingleton(as: DiagnosisRepository)
class DiagnosisRepositoryImpl implements DiagnosisRepository {
  final DiseaseKnowledgeRepository knowledgeRepository;

  /// Détecteur de culture utilisé pour filtrer les modèles hors-domaine
  /// avant la fusion. Par défaut [HeuristicCultureDetector] qui se base
  /// sur la prédiction plantvillage. Injectable pour les tests et pour
  /// brancher un vrai modèle TFLite le jour où il existera.
  final CultureDetector cultureDetector;

  DiagnosisRepositoryImpl({
    required this.knowledgeRepository,
    this.cultureDetector = const HeuristicCultureDetector(),
  });

  @override
  Future<Either<Failure, DiagnosisResult>> analyzeImage(
    String imagePath,
  ) async {
    try {
      final modelManager = ModelManager.instance;
      if (!modelManager.isReady) {
        // Le chargement des modèles est différé en background depuis main.dart.
        // On attend jusqu'à 6 s pour couvrir la race condition rare où
        // l'utilisateur lance un diagnostic très rapidement après le démarrage.
        const step = Duration(milliseconds: 250);
        const maxWait = Duration(seconds: 6);
        var waited = Duration.zero;
        while (!modelManager.isReady && waited < maxWait) {
          await Future.delayed(step);
          waited += step;
        }
        if (!modelManager.isReady) {
          return const Left(
            ModelFailure(
              'Le modèle IA est encore en cours de chargement. '
              'Veuillez patienter un instant et réessayer.',
            ),
          );
        }
      }

      // ── Stratégie multi-modèle ──
      // Phase 1 : exécuter chaque modèle, collecter candidates +
      //           évidences pour le détecteur de culture.
      // Phase 2 : détecter le domaine (ex. plantvillage dit "Tomato" à 80 %).
      // Phase 3 : filtrer les candidates dont le modèle est hors-domaine
      //           (ex. cassava sur une photo identifiée comme tomate).
      // Phase 4 : fusionner les survivants (knowledge entry prime, sinon
      //           confiance la plus élevée).
      final candidates = <_Best>[];
      final evidences = <ModelEvidence>[];

      // Probabilité Background_without_leaves maximum vue sur l'ensemble
      // des modèles. Si > kBackgroundRejectThreshold, on rejette l'image
      // même si Background n'est pas top-1 (QW4 : un modèle "hésite"
      // entre une maladie et le fait que l'image n'a pas de feuille
      // claire → on préfère redemander une photo plutôt que diagnostiquer).
      double maxBackgroundProb = 0.0;

      for (final loaded in _modelsToRun(modelManager)) {
        final preprocessed = await preprocessImage(
          imagePath,
          inputSize: loaded.profile.inputSize,
          mean: loaded.profile.mean,
          std: loaded.profile.std,
        );

        final result = _runInferenceFor(loaded, preprocessed);
        if (result == null) continue;

        if (result.backgroundProb != null &&
            result.backgroundProb! > maxBackgroundProb) {
          maxBackgroundProb = result.backgroundProb!;
        }

        evidences.add(ModelEvidence(
          modelId: loaded.profile.id,
          topLabel: result.topLabel,
          topConfidence: result.topConfidence,
          backgroundProb: result.backgroundProb,
        ));

        final knownInfo =
            knowledgeRepository.getDiseaseByLabel(result.topLabel);
        candidates.add(_Best(
          rawLabel: result.topLabel,
          confidence: result.topConfidence,
          margin: result.margin,
          info: knownInfo,
          modelId: loaded.profile.id,
          modelDomainPrefixes: loaded.domainPrefixes,
        ));
      }

      if (candidates.isEmpty) {
        return const Left(ModelFailure('Aucun résultat concluant.'));
      }

      // C3 — Détection de culture : si plantvillage dit "Tomato" à 80 %,
      // le détecteur retourne plausibleCultures={'Tomato'}. On filtre
      // alors les candidats issus de modèles dont aucun préfixe ne
      // matche → cassava est éliminé sur une photo tomate.
      final domain = cultureDetector.detect(evidences);
      final survivors = _filterByDomain(candidates, domain);

      _Best? best;
      for (final candidate in survivors) {
        if (best == null) {
          best = candidate;
        } else {
          // Un diagnostic "réel" (maladie connue ≠ Cassava___unknown) prime
          // toujours sur la classe fourre-tout "Cassava___unknown" du modèle
          // cassava, même si sa confiance est plus basse. Cette classe ne
          // gagne que si aucun autre modèle n'a trouvé de maladie identifiable.
          final bestIsReal = _isRealDiagnosis(best);
          final candidateIsReal = _isRealDiagnosis(candidate);
          if (candidateIsReal && !bestIsReal) {
            best = candidate;
          } else if (bestIsReal == candidateIsReal &&
              candidate.confidence > best.confidence) {
            best = candidate;
          }
        }
      }

      if (best == null) {
        return const Left(ModelFailure('Aucun résultat concluant.'));
      }

      // QW4 — Rejet précoce : Background suffisamment haut sur AU MOINS un
      // modèle, indépendamment de qui a gagné la fusion. Évite les
      // faux diagnostics sur des photos majoritairement hors-sujet.
      if (shouldRejectAsBackground(maxBackgroundProb)) {
        return Right(
          _buildBackgroundRejection(imagePath, maxBackgroundProb),
        );
      }

      final needsValidation = shouldRequestValidation(
        confidence: best.confidence,
        margin: best.margin,
      );

      // Filet de sécurité : rejet aussi si Background est carrément
      // top-1 du modèle gagnant (cas typique d'image entièrement vide
      // où la confiance Background peut rester sous le seuil tout en
      // étant la classe gagnante).
      if (isBackgroundLabel(best.rawLabel)) {
        return Right(
          DiagnosisResult(
            label: 'Image inutilisable',
            confidence: best.confidence,
            imagePath: imagePath,
            treatmentAdvice:
                'L\'image ne contient pas de feuille bien visible. '
                'Reprenez la photo avec une feuille au centre, '
                'sur un fond uniforme et avec un bon éclairage.',
            diseaseName: 'Image inutilisable',
            diseaseDescription:
                'L\'IA n\'a pas trouvé de feuille analysable. '
                'Cadrez une feuille seule, à plat, à 20 cm de distance.',
            severity: 'aucune',
            needsValidation: true,
            rawModelLabel: best.rawLabel,
          ),
        );
      }

      if (best.info != null) {
        final info = best.info!;
        final treatmentText = _buildTreatmentText(info);

        return Right(
          DiagnosisResult(
            label: info.displayName,
            confidence: best.confidence,
            imagePath: imagePath,
            treatmentAdvice: treatmentText,
            diseaseName: info.displayName,
            diseaseDescription: info.description,
            severity: info.severity,
            needsValidation: needsValidation,
            rawModelLabel: best.rawLabel,
          ),
        );
      }

      final formattedLabel = _formatLabel(best.rawLabel);
      return Right(
        DiagnosisResult(
          label: formattedLabel,
          confidence: best.confidence,
          imagePath: imagePath,
          treatmentAdvice:
              'Diagnostic identifié : $formattedLabel.\n\n'
              'Consultez un agronome ou un spécialiste pour confirmer '
              'ce diagnostic et obtenir un traitement adapté.',
          diseaseName: formattedLabel,
          diseaseDescription:
              'Maladie identifiée par l\'IA mais pas encore documentée '
              'dans notre base de connaissances.',
          severity: 'inconnu',
          needsValidation: true,
          rawModelLabel: best.rawLabel,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur analyse: $e');
      return Left(CacheFailure('Erreur lors de l\'analyse: ${e.toString()}'));
    }
  }

  /// Sélectionne les modèles à exécuter pour ce diagnostic.
  /// Par défaut on exécute tous les modèles chargés (rapide en TFLite).
  Iterable<LoadedModel> _modelsToRun(ModelManager mgr) {
    final all = mgr.availableProfiles
        .map((p) => mgr.getById(p.id))
        .whereType<LoadedModel>()
        .toList();
    return all.isEmpty ? [if (mgr.active != null) mgr.active!] : all;
  }

  _InferenceOutput? _runInferenceFor(
    LoadedModel loaded,
    PreprocessedImage preprocessed,
  ) {
    final interpreter = loaded.interpreter;
    final labels = loaded.labels;
    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outputType = outputTensor.type;
    final numClasses = outputShape[1];

    dynamic output;
    if (outputType == TensorType.uint8) {
      output = Uint8List(numClasses).buffer;
    } else {
      output = List.generate(1, (_) => List.filled(numClasses, 0.0));
    }

    final inputTensor = interpreter.getInputTensor(0);
    final inputType = inputTensor.type;

    final dynamic input = inputType == TensorType.uint8
        ? preprocessed.uint8Pixels.buffer
        : preprocessed.float32Input.buffer;

    interpreter.run(input, output);

    final List<double> rawValues;
    if (outputType == TensorType.uint8) {
      final quantParams = outputTensor.params;
      final rawOutput = (output as ByteBuffer).asUint8List();
      rawValues = List<double>.generate(
        numClasses,
        (i) => (rawOutput[i] - quantParams.zeroPoint) * quantParams.scale,
      );
    } else {
      final rawList = output[0];
      rawValues = rawList
          .map<num>((e) => e as num)
          .map((e) => e.toDouble())
          .toList();
    }

    // Les modèles embarqués exportent une couche softmax finale : leur sortie
    // est DÉJÀ une distribution de probabilités. Leur ré-appliquer un softmax
    // (calibratedSoftmax) serait un double softmax qui écrase la confiance
    // (99 % → ~35 % sur 6 classes, ~7 % sur 39). On route donc selon le type
    // de sortie déclaré par le profil, avec auto-détection en repli.
    final outputsProbabilities = loaded.profile.outputsProbabilities ??
        looksLikeProbabilities(rawValues);
    final probs = outputsProbabilities
        ? temperatureScaleProbabilities(
            rawValues,
            temperature: loaded.profile.temperature,
          )
        : calibratedSoftmax(
            rawValues,
            temperature: loaded.profile.temperature,
          );
    if (probs.isEmpty) return null;

    // Top-1, top-2 et prob(Background) en un seul pas (O(n)) plutôt
    // que de trier ou de boucler trois fois.
    int topIdx = 0;
    double topProb = probs[0];
    double secondProb = 0.0;
    double? backgroundProb;
    if (isBackgroundLabel(labels[0])) backgroundProb = probs[0];

    for (int i = 1; i < probs.length; i++) {
      final p = probs[i];
      if (p > topProb) {
        secondProb = topProb;
        topProb = p;
        topIdx = i;
      } else if (p > secondProb) {
        secondProb = p;
      }
      if (backgroundProb == null && isBackgroundLabel(labels[i])) {
        backgroundProb = p;
      }
    }

    if (topIdx < 0 || topIdx >= labels.length) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Model ${loaded.profile.id}: index $topIdx hors labels (${labels.length})',
        );
      }
      return null;
    }

    final rawLabel = labels[topIdx];
    if (kDebugMode) {
      final marginPct = ((topProb - secondProb) * 100).toStringAsFixed(1);
      final bgStr = backgroundProb != null
          ? ', bg ${(backgroundProb * 100).toStringAsFixed(1)}%'
          : '';
      debugPrint(
        '🏷️ ${loaded.profile.id}: $rawLabel '
        '(${(topProb * 100).toStringAsFixed(1)}%, marge $marginPct pts$bgStr)',
      );
    }
    return _InferenceOutput(
      topLabel: rawLabel,
      topConfidence: topProb,
      secondConfidence: secondProb,
      backgroundProb: backgroundProb,
    );
  }

  String _buildTreatmentText(DiseaseInfo info) {
    final buffer = StringBuffer();

    if (info.isHealthy) {
      buffer.writeln(info.description);
      if (info.treatments.isNotEmpty) {
        buffer.writeln();
        for (final step in info.treatments.first.steps) {
          buffer.writeln('• $step');
        }
      }
      return buffer.toString().trim();
    }

    for (final treatment in info.treatments) {
      buffer.writeln('${treatment.method} :');
      for (final step in treatment.steps) {
        buffer.writeln('  • $step');
      }
      buffer.writeln();
    }

    if (info.products.isNotEmpty) {
      buffer.writeln('Produits recommandés :');
      for (final product in info.products) {
        buffer.writeln('  • ${product.name}');
        buffer.writeln('    Dosage : ${product.dosage}');
      }
    }

    return buffer.toString().trim();
  }

  /// Retourne true si le candidat est un diagnostic de maladie réelle,
  /// c'est-à-dire qu'il est documenté dans la base de connaissances ET
  /// qu'il ne s'agit pas de la classe fourre-tout "Cassava___unknown" du
  /// modèle cassava. Cette classe ne doit l'emporter que si aucun autre
  /// modèle n'a trouvé de maladie identifiable (plante hors dataset
  /// d'entraînement).
  bool _isRealDiagnosis(_Best candidate) =>
      candidate.info != null && candidate.rawLabel != 'Cassava___unknown';

  /// Filtre les candidats par compatibilité avec le domaine détecté.
  ///
  /// Un candidat est conservé si **au moins un** des préfixes de domaine
  /// de son modèle d'origine est supporté par [domain]. Si le filtre
  /// élimine tout le monde (cas extrême — domaine détecté ne matche
  /// AUCUN modèle), on retourne la liste originale en failsafe : mieux
  /// vaut un diagnostic incertain qu'aucun diagnostic du tout.
  ///
  /// Cette logique est ce qui résout le bug "cassava-healthy gagne sur
  /// une photo tomate" décrit dans l'audit (C3) : quand le détecteur
  /// dit "image probablement Tomato à 80 %", le candidat cassava (dont
  /// les préfixes sont {'Cassava'}) ne supporte aucune des cultures
  /// détectées → il est éliminé de la fusion.
  List<_Best> _filterByDomain(List<_Best> candidates, DomainEvidence domain) {
    final survivors = candidates
        .where((c) => c.modelDomainPrefixes.any(domain.supportsCulture))
        .toList();
    return survivors.isEmpty ? candidates : survivors;
  }

  /// Construit le DiagnosisResult standard de rejet "image inutilisable",
  /// utilisé à la fois par la règle QW4 (Background prob > seuil) et par
  /// le filet de sécurité top-1.
  DiagnosisResult _buildBackgroundRejection(
    String imagePath,
    double confidence,
  ) {
    return DiagnosisResult(
      label: 'Image inutilisable',
      confidence: confidence,
      imagePath: imagePath,
      treatmentAdvice:
          'L\'image ne contient pas de feuille bien visible. '
          'Reprenez la photo avec une feuille au centre, '
          'sur un fond uniforme et avec un bon éclairage.',
      diseaseName: 'Image inutilisable',
      diseaseDescription:
          'L\'IA n\'a pas trouvé de feuille analysable. '
          'Cadrez une feuille seule, à plat, à 20 cm de distance.',
      severity: 'aucune',
      needsValidation: true,
      rawModelLabel: 'Background_without_leaves',
    );
  }

  String _formatLabel(String rawLabel) {
    return rawLabel
        .replaceAll('___', ' - ')
        .replaceAll('_', ' ')
        .replaceAll(' healthy', ' (Sain)')
        .trim();
  }
}

class _Best {
  final String rawLabel;
  final double confidence;

  /// Écart top-1 − top-2 (en probabilité softmax) sur le modèle qui a
  /// produit ce candidat. Utilisé pour détecter les diagnostics ambigus
  /// même quand la confiance brute est au-dessus du seuil.
  final double margin;
  final DiseaseInfo? info;
  final String modelId;

  /// Préfixes de domaine (cultures supportées) du modèle d'origine, pour
  /// permettre au filtre culture-detector (C3) de savoir si ce candidat
  /// est pertinent pour le domaine détecté.
  final Set<String> modelDomainPrefixes;

  const _Best({
    required this.rawLabel,
    required this.confidence,
    required this.margin,
    required this.info,
    required this.modelId,
    required this.modelDomainPrefixes,
  });
}

/// Sortie structurée d'une inférence sur un modèle donné. Conserve à la
/// fois le top-1, le top-2 et la probabilité de la classe "Background"
/// (si le modèle en possède une) pour permettre l'aval de :
///   - calculer la marge top-1 − top-2 (QW3)
///   - rejeter l'image dès que le modèle voit beaucoup de background,
///     même si Background n'est pas top-1 (QW4)
/// sans avoir à re-trier les probabilités.
class _InferenceOutput {
  final String topLabel;
  final double topConfidence;
  final double secondConfidence;

  /// Probabilité softmax de la classe `Background_without_leaves` si le
  /// modèle la possède (PlantVillage), sinon `null` (cassava).
  final double? backgroundProb;

  const _InferenceOutput({
    required this.topLabel,
    required this.topConfidence,
    required this.secondConfidence,
    this.backgroundProb,
  });

  double get margin => topConfidence - secondConfidence;
}
