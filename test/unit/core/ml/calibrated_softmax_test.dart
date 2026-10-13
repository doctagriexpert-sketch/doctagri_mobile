import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/core/ml/model_manager.dart';

/// Tests unitaires de la fonction pure [calibratedSoftmax].
///
/// La calibration de température aplatit (T > 1) ou pique (T < 1) la
/// distribution softmax sans changer le classement des classes
/// (l'argmax est invariant). Ces tests vérifient ce comportement
/// mathématique ainsi que les garde-fous.
void main() {
  group('calibratedSoftmax', () {
    test('T=1.0 (défaut) → softmax standard', () {
      // Référence : softmax([1, 2, 3]) ≈ [0.0900, 0.2447, 0.6652]
      final probs = calibratedSoftmax([1.0, 2.0, 3.0]);
      expect(probs.length, 3);
      expect(probs[0], closeTo(0.0900, 1e-3));
      expect(probs[1], closeTo(0.2447, 1e-3));
      expect(probs[2], closeTo(0.6652, 1e-3));
    });

    test('sortie somme toujours à 1, quel que soit T', () {
      for (final t in [0.5, 1.0, 1.5, 2.0, 5.0, 10.0]) {
        final probs = calibratedSoftmax([0.5, 1.5, 2.5, 3.5], temperature: t);
        final sum = probs.reduce((a, b) => a + b);
        expect(sum, closeTo(1.0, 1e-6), reason: 'T=$t');
      }
    });

    test('T > 1 aplatit : top-1 baisse, classes basses remontent', () {
      final logits = [3.0, 1.0, 0.5];
      final t1 = calibratedSoftmax(logits, temperature: 1.0);
      final t2 = calibratedSoftmax(logits, temperature: 2.0);
      final t5 = calibratedSoftmax(logits, temperature: 5.0);

      // Top-1 baisse de manière monotone avec T croissant
      expect(t2[0], lessThan(t1[0]));
      expect(t5[0], lessThan(t2[0]));

      // Et les autres classes remontent
      expect(t2[1], greaterThan(t1[1]));
      expect(t2[2], greaterThan(t1[2]));
    });

    test('T < 1 pique : top-1 monte', () {
      final logits = [3.0, 1.0, 0.5];
      final t1 = calibratedSoftmax(logits, temperature: 1.0);
      final tHalf = calibratedSoftmax(logits, temperature: 0.5);

      expect(tHalf[0], greaterThan(t1[0]));
      expect(tHalf[1], lessThan(t1[1]));
    });

    test('argmax invariant sous toute T > 0', () {
      // Le classement des classes ne doit jamais changer avec la
      // température. C'est la propriété clé qui justifie qu'on peut
      // calibrer post-entraînement sans toucher au modèle.
      final logits = [1.2, 4.8, 2.1, 0.3, 3.7];
      const expectedArgmax = 1;
      for (final t in [0.1, 0.5, 1.0, 2.0, 10.0, 100.0]) {
        final probs = calibratedSoftmax(logits, temperature: t);
        final argmax = probs.indexOf(probs.reduce(math.max));
        expect(argmax, expectedArgmax, reason: 'T=$t');
      }
    });

    test('liste vide retourne liste vide', () {
      expect(calibratedSoftmax(const []), isEmpty);
      expect(calibratedSoftmax(const [], temperature: 2.0), isEmpty);
    });

    test('numériquement stable pour logits extrêmes', () {
      // softmax([1000, 999, 998]) doit retourner [~0.665, ~0.245, ~0.090]
      // (les mêmes valeurs que softmax([2, 1, 0]) parce qu'on soustrait
      // le max). Sans le « max subtract trick » on aurait `exp(1000)` = inf.
      final probs = calibratedSoftmax([1000.0, 999.0, 998.0]);
      expect(probs[0], closeTo(0.665, 1e-3));
      expect(probs[1], closeTo(0.245, 1e-3));
      expect(probs[2], closeTo(0.090, 1e-3));
      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-6));
    });

    test('T très grand → distribution quasi-uniforme', () {
      // Limite T → ∞ : softmax converge vers 1/N pour chaque classe.
      final probs = calibratedSoftmax([
        0.0,
        5.0,
        10.0,
        15.0,
      ], temperature: 1000.0);
      const uniform = 0.25;
      for (final p in probs) {
        expect(p, closeTo(uniform, 1e-2));
      }
    });

    test('T → 0+ : distribution quasi one-hot sur l\'argmax', () {
      // Limite T → 0 : softmax devient un argmax dur (1 sur le max,
      // 0 ailleurs). Avec T très petit on doit s'en approcher.
      final probs = calibratedSoftmax([1.0, 5.0, 2.0], temperature: 0.01);
      expect(probs[1], closeTo(1.0, 1e-6));
      expect(probs[0], closeTo(0.0, 1e-6));
      expect(probs[2], closeTo(0.0, 1e-6));
    });

    test('assertion lève si T <= 0 (debug uniquement)', () {
      // Garde-fou : T ≤ 0 n'a aucun sens mathématique.
      // assert() est strippé en release mode → ce test ne fait foi
      // que dans les builds debug/test.
      expect(
        () => calibratedSoftmax([1.0, 2.0], temperature: 0.0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => calibratedSoftmax([1.0, 2.0], temperature: -1.0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ModelProfile.temperature', () {
    test('défaut à 1.0', () {
      const profile = ModelProfile(
        id: 'test',
        displayName: 'Test',
        assetPath: 'x',
        labelsAssetPath: 'y',
      );
      expect(profile.temperature, equals(1.0));
    });

    test('assertion lève si T <= 0', () {
      expect(
        () => ModelProfile(
          id: 'test',
          displayName: 'Test',
          assetPath: 'x',
          labelsAssetPath: 'y',
          temperature: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
