import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/features/diagnosis/data/repositories/diagnosis_repository_impl.dart';

/// Tests unitaires de la règle pure de décision de validation humaine.
///
/// La règle combine trois signaux indépendants :
///   1. confiance < [kConfidenceThreshold] (0.5) → diagnostic peu sûr
///   2. marge top-1 − top-2 < [kAmbiguityMargin] (0.1) → diagnostic ambigu
///   3. entropie > [kMaxEntropyForConfidentDiagnosis] (0.6) → distribution
///      diffuse, signal d'entrée hors-distribution (risque labo→terrain)
///
/// Le modèle n'est pas sûr en valeur absolue, OU hésite entre deux classes
/// proches, OU répartit sa probabilité sur de nombreuses classes : dans tous
/// les cas on demande une validation experte.
void main() {
  group('shouldRequestValidation', () {
    test('haute confiance + grande marge → false', () {
      // Cas "modèle confiant et tranché" : ne demande pas de validation.
      expect(
        shouldRequestValidation(confidence: 0.85, margin: 0.40),
        isFalse,
      );
    });

    test('haute confiance + marge faible → true (cas QW3)', () {
      // C'EST LE CAS QUE QW3 INTRODUIT.
      // Avant : 0.62 > 0.5 → needsValidation=false (faux confort).
      // Après : top-1 0.62 et top-2 0.55 → marge 0.07 < 0.1 → true.
      expect(
        shouldRequestValidation(confidence: 0.62, margin: 0.07),
        isTrue,
      );
    });

    test('basse confiance + grande marge → true (cas pré-existant)', () {
      // Comportement historique : confiance < 0.5 déclenche déjà la
      // validation. La marge ne change rien à ce cas.
      expect(
        shouldRequestValidation(confidence: 0.30, margin: 0.25),
        isTrue,
      );
    });

    test('basse confiance + marge faible → true', () {
      expect(
        shouldRequestValidation(confidence: 0.30, margin: 0.02),
        isTrue,
      );
    });

    test('au seuil exact (confiance = 0.5) → true', () {
      // Le seuil est strict (`< kConfidenceThreshold`), donc 0.5 pile
      // n'est PAS sous le seuil → seule la marge peut déclencher.
      expect(
        shouldRequestValidation(confidence: 0.5, margin: 0.40),
        isFalse,
      );
    });

    test('au seuil exact (marge = 0.1) → false', () {
      // Idem : `< kAmbiguityMargin` strict, donc 0.1 pile ne déclenche pas.
      expect(
        shouldRequestValidation(confidence: 0.85, margin: 0.1),
        isFalse,
      );
    });

    test('marge nulle (top-1 == top-2) → true même à haute confiance', () {
      // Cas limite : deux classes ex æquo. Confiance arbitraire élevée.
      expect(
        shouldRequestValidation(confidence: 0.95, margin: 0.0),
        isTrue,
      );
    });

    test('constantes exposées sont raisonnables', () {
      // Garde-fou : si on baisse trop le seuil d'ambiguïté, on rate les
      // cas que QW3 veut justement attraper. Si on le monte trop, on
      // demande trop de validations. 0.1 ± un peu reste un bon compromis.
      expect(kConfidenceThreshold, equals(0.5));
      expect(kAmbiguityMargin, equals(0.1));
      expect(kMaxEntropyForConfidentDiagnosis, equals(0.6));
    });

    // ── Signal d'entropie (point 4 : robustesse hors-distribution) ──

    test('confiance + marge OK mais entropie haute → true', () {
      // Le cas que les seuils LOCAUX laissent passer : top-1 confortable et
      // bien détaché du top-2, mais la masse restante est étalée sur de
      // nombreuses classes (entrée hors-distribution). L'entropie l'attrape.
      expect(
        shouldRequestValidation(confidence: 0.7, margin: 0.4, entropy: 0.75),
        isTrue,
      );
    });

    test('confiance + marge OK et entropie basse → false', () {
      expect(
        shouldRequestValidation(confidence: 0.7, margin: 0.4, entropy: 0.2),
        isFalse,
      );
    });

    test('entropie au seuil exact (0.6) → false (strict)', () {
      expect(
        shouldRequestValidation(confidence: 0.9, margin: 0.5, entropy: 0.6),
        isFalse,
      );
    });

    test('entropie par défaut (0.0) ne déclenche jamais — rétrocompat', () {
      // Les appelants historiques (confidence, margin) restent inchangés.
      expect(
        shouldRequestValidation(confidence: 0.9, margin: 0.5),
        isFalse,
      );
    });
  });

  group('normalizedEntropy', () {
    test('distribution one-hot → 0 (certitude)', () {
      expect(normalizedEntropy([1.0, 0.0, 0.0, 0.0]), closeTo(0.0, 1e-9));
    });

    test('distribution uniforme → 1 (ignorance totale)', () {
      expect(normalizedEntropy([0.25, 0.25, 0.25, 0.25]), closeTo(1.0, 1e-9));
      expect(
        normalizedEntropy(List.filled(39, 1 / 39)),
        closeTo(1.0, 1e-9),
      );
    });

    test('quasi one-hot → entropie faible', () {
      expect(normalizedEntropy([0.97, 0.01, 0.01, 0.01]), lessThan(0.2));
    });

    test('distribution diffuse → entropie élevée', () {
      // Top-1 modeste, longue traîne : exactement le cas hors-distribution.
      final diffuse = [0.2, 0.15, 0.13, 0.12, 0.11, 0.10, 0.10, 0.09];
      expect(normalizedEntropy(diffuse), greaterThan(0.9));
    });

    test('normalisation indépendante du nombre de classes', () {
      // Une uniforme donne 1.0 que ce soit sur 6 ou 39 classes : le seuil
      // est comparable entre cassava et plantvillage.
      expect(normalizedEntropy(List.filled(6, 1 / 6)), closeTo(1.0, 1e-9));
      expect(normalizedEntropy(List.filled(39, 1 / 39)), closeTo(1.0, 1e-9));
    });

    test('valeur connue : softmax([1,2,3]) ≈ 0.83', () {
      // Référence calculée : H = 0.8132 nats, /log(3)=1.0986 → 0.7402.
      final probs = [0.0900, 0.2447, 0.6652];
      final h = -probs.fold<double>(
        0.0,
        (a, p) => a + p * math.log(p),
      );
      expect(normalizedEntropy(probs), closeTo(h / math.log(3), 1e-3));
    });

    test('< 2 classes → 0 (dégénéré)', () {
      expect(normalizedEntropy(const []), 0.0);
      expect(normalizedEntropy([1.0]), 0.0);
    });
  });
}
