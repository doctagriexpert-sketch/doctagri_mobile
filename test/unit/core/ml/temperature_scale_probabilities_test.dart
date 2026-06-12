import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/core/ml/model_manager.dart';
import 'package:doctagri/features/diagnosis/data/repositories/diagnosis_repository_impl.dart';

/// Tests unitaires de [temperatureScaleProbabilities] et [looksLikeProbabilities].
///
/// Contexte : les modèles embarqués exportent une couche softmax finale —
/// leur sortie est déjà une distribution de probabilités. La voie correcte est
/// de recalibrer ces probabilités sans leur ré-appliquer un softmax (ce qui
/// serait un double softmax, écrasant la confiance 99 % → ~7 % sur 39 classes).
void main() {
  group('temperatureScaleProbabilities', () {
    test('T=1.0 renormalise sans changer la forme (pas de double softmax)', () {
      // Sortie quantifiée typique : somme 255/256, quasi one-hot.
      final raw = [0.9961, 0.0, 0.0, 0.0, 0.0, 0.0];
      final out = temperatureScaleProbabilities(raw);
      expect(out.length, 6);
      expect(out.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      // La confiance top-1 reste ~1.0 — PAS écrasée à ~0.35 comme le ferait
      // un softmax appliqué par-dessus.
      expect(out[0], closeTo(1.0, 1e-3));
    });

    test('contraste avec le bug : softmax-sur-proba écraserait la confiance',
        () {
      final raw = [0.9961, 0.0, 0.0, 0.0, 0.0, 0.0];
      final correct = temperatureScaleProbabilities(raw);
      final buggy = calibratedSoftmax(raw); // l'ancien comportement
      expect(correct[0], greaterThan(0.99));
      expect(buggy[0], lessThan(0.40)); // ~0.35 : la preuve du bug
    });

    test('sortie somme toujours à 1, quel que soit T', () {
      for (final t in [0.5, 1.0, 1.5, 2.0, 5.0]) {
        final out = temperatureScaleProbabilities(
          [0.7, 0.2, 0.1],
          temperature: t,
        );
        expect(out.reduce((a, b) => a + b), closeTo(1.0, 1e-9), reason: 'T=$t');
      }
    });

    test('argmax invariant sous toute T > 0', () {
      final raw = [0.1, 0.6, 0.3];
      for (final t in [0.3, 1.0, 2.0, 8.0]) {
        final out = temperatureScaleProbabilities(raw, temperature: t);
        int argmax = 0;
        for (int i = 1; i < out.length; i++) {
          if (out[i] > out[argmax]) argmax = i;
        }
        expect(argmax, 1, reason: 'T=$t');
      }
    });

    test('T > 1 aplatit : top-1 baisse', () {
      final raw = [0.8, 0.15, 0.05];
      final base = temperatureScaleProbabilities(raw);
      final flat = temperatureScaleProbabilities(raw, temperature: 3.0);
      expect(flat[0], lessThan(base[0]));
    });

    test('T < 1 pique : top-1 monte', () {
      final raw = [0.6, 0.25, 0.15];
      final base = temperatureScaleProbabilities(raw);
      final sharp = temperatureScaleProbabilities(raw, temperature: 0.5);
      expect(sharp[0], greaterThan(base[0]));
    });

    test('liste vide → liste vide', () {
      expect(temperatureScaleProbabilities(const []), isEmpty);
    });

    test('robuste aux valeurs négatives de bruit de quantification', () {
      final out = temperatureScaleProbabilities(
        [0.99, -0.001, 0.011],
        temperature: 2.0,
      );
      expect(out.length, 3);
      expect(out.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      for (final p in out) {
        expect(p, greaterThanOrEqualTo(0.0));
      }
    });

    test('somme nulle → distribution uniforme (pas de NaN)', () {
      final out = temperatureScaleProbabilities([0.0, 0.0, 0.0, 0.0]);
      expect(out, everyElement(closeTo(0.25, 1e-9)));
    });
  });

  group('looksLikeProbabilities', () {
    test('distribution normalisée (somme ≈ 1, ≥ 0) → true', () {
      expect(looksLikeProbabilities([0.7, 0.2, 0.1]), isTrue);
    });

    test('sortie uint8 sommant à 255/256 ≈ 0.996 → true', () {
      expect(looksLikeProbabilities([0.9961, 0.0, 0.0]), isTrue);
    });

    test('logits (somme arbitraire, valeurs négatives) → false', () {
      expect(looksLikeProbabilities([2.3, -1.1, 5.0, 0.4]), isFalse);
    });

    test('valeurs positives mais somme ≠ 1 → false', () {
      expect(looksLikeProbabilities([3.0, 1.0, 2.0]), isFalse);
    });

    test('liste vide → false', () {
      expect(looksLikeProbabilities(const []), isFalse);
    });
  });
}
