import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/features/diagnosis/data/repositories/diagnosis_repository_impl.dart';

/// Tests unitaires de la règle pure de décision de validation humaine.
///
/// La règle combine deux signaux indépendants :
///   1. confiance < [kConfidenceThreshold] (0.5) → diagnostic peu sûr
///   2. marge top-1 − top-2 < [kAmbiguityMargin] (0.1) → diagnostic ambigu
///
/// Soit le modèle n'est pas sûr en valeur absolue, soit il hésite entre
/// deux classes proches : dans les deux cas on demande une validation.
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
    });
  });
}
