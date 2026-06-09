import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/core/ml/culture_detector.dart';

/// Tests unitaires pour le module de détection de culture (C3).
///
/// Trois groupes :
///   1. [extractCultureFromLabel] — extraction de préfixe depuis un label.
///   2. [DomainEvidence] — sémantique de supports/excludes.
///   3. [HeuristicCultureDetector] — scénarios métier (le cœur de C3).
void main() {
  group('extractCultureFromLabel', () {
    test('label PlantVillage `Culture___disease` → préfixe Culture', () {
      expect(extractCultureFromLabel('Tomato___Early_blight'), 'Tomato');
      expect(extractCultureFromLabel('Apple___healthy'), 'Apple');
      expect(extractCultureFromLabel('Cherry___Powdery_mildew'), 'Cherry');
    });

    test('label cassava namespacé `Cassava___xxx`', () {
      expect(extractCultureFromLabel('Cassava___healthy'), 'Cassava');
      expect(extractCultureFromLabel('Cassava___unknown'), 'Cassava');
    });

    test('label cassava historique `Cassava <maladie>` → Cassava', () {
      expect(
        extractCultureFromLabel('Cassava Bacterial Blight (CBB)'),
        'Cassava',
      );
      expect(
        extractCultureFromLabel('Cassava Mosaic Disease (CMD)'),
        'Cassava',
      );
    });

    test('Background_without_leaves → null (pas une culture)', () {
      expect(extractCultureFromLabel('Background_without_leaves'), isNull);
    });

    test('label inconnu non préfixé → null', () {
      expect(extractCultureFromLabel('SomeRandomLabel'), isNull);
      expect(extractCultureFromLabel(''), isNull);
    });

    test('label avec __ tout début → null (préfixe vide)', () {
      expect(extractCultureFromLabel('___healthy'), isNull);
    });
  });

  group('DomainEvidence', () {
    test('unknown : supporte tout, n\'exclut rien', () {
      final d = DomainEvidence.unknown();
      expect(d.supportsCulture('Tomato'), isTrue);
      expect(d.supportsCulture('Cassava'), isTrue);
      expect(d.excludesCulture('Tomato'), isFalse);
      expect(d.excludesCulture('Cassava'), isFalse);
    });

    test('avec évidence Tomato à 80 % : exclut les autres cultures', () {
      const d = DomainEvidence(
        plausibleCultures: {'Tomato'},
        confidence: 0.8,
      );
      expect(d.supportsCulture('Tomato'), isTrue);
      expect(d.supportsCulture('Cassava'), isFalse);
      expect(d.excludesCulture('Tomato'), isFalse);
      expect(d.excludesCulture('Cassava'), isTrue);
    });

    test('confiance < 0.5 : n\'exclut PAS, mais ne supporte que les '
        'cultures listées (cas limite peu utilisé)', () {
      const d = DomainEvidence(
        plausibleCultures: {'Tomato'},
        confidence: 0.3,
      );
      expect(d.supportsCulture('Tomato'), isTrue);
      expect(d.supportsCulture('Cassava'), isFalse);
      // Pas assez confiant pour EXCLURE
      expect(d.excludesCulture('Cassava'), isFalse);
    });
  });

  group('HeuristicCultureDetector', () {
    const detector = HeuristicCultureDetector();

    test('aucune évidence → unknown', () {
      final d = detector.detect(const []);
      expect(d.plausibleCultures, isEmpty);
      expect(d.confidence, 0.0);
    });

    test('seul cassava présent → unknown (plantvillage absent)', () {
      // Pas de plantvillage = on ne sait rien sur le domaine.
      // Important : on ne déduit PAS du fait que cassava prédit
      // quelque chose que l'image est manioc — cassava classifie de
      // force, c'est le problème qu'on essaie de résoudre.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'cassava',
          topLabel: 'Cassava___healthy',
          topConfidence: 0.85,
        ),
      ]);
      expect(d.plausibleCultures, isEmpty);
    });

    test('plantvillage confiant non-Background → culture extraite', () {
      // Scénario clé du bug C3 : plantvillage dit "Tomato" à 80 %.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Tomato___Early_blight',
          topConfidence: 0.8,
          backgroundProb: 0.05,
        ),
        ModelEvidence(
          modelId: 'cassava',
          topLabel: 'Cassava___healthy',
          topConfidence: 0.85,
        ),
      ]);
      expect(d.plausibleCultures, {'Tomato'});
      expect(d.confidence, 0.8);
      // Conséquence métier : cassava doit être exclu
      expect(d.excludesCulture('Cassava'), isTrue);
      expect(d.supportsCulture('Tomato'), isTrue);
    });

    test('plantvillage avec Background > 0.25 → unknown', () {
      // Image douteuse : on ne tire AUCUNE conclusion sur la culture.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Tomato___Early_blight',
          topConfidence: 0.6,
          backgroundProb: 0.30,
        ),
      ]);
      expect(d.plausibleCultures, isEmpty);
    });

    test('plantvillage faible confiance → unknown', () {
      // Si plantvillage hésite (top-1 = 0.4), on ne sait pas si c'est
      // bien la culture indiquée. On préfère ne rien conclure plutôt
      // que d'éliminer cassava à tort.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Tomato___Early_blight',
          topConfidence: 0.4,
        ),
      ]);
      expect(d.plausibleCultures, isEmpty);
    });

    test('plantvillage à 0.5 pile → culture extraite (seuil inclusif)', () {
      // Le code utilise `< 0.5` strict → 0.5 pile passe le filtre.
      // Cohérent avec [kConfidenceThreshold] dans le repository qui
      // utilise aussi `< 0.5` strict pour [shouldRequestValidation].
      // Note : DomainEvidence.excludesCulture exige `>= 0.5` → 0.5
      // pile suffit à exclure cassava. C'est par symétrie volontaire.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Tomato___Early_blight',
          topConfidence: 0.5,
        ),
      ]);
      expect(d.plausibleCultures, {'Tomato'});
      expect(d.excludesCulture('Cassava'), isTrue);
    });

    test('plantvillage prédit cassava → impossible mais robuste', () {
      // PlantVillage ne contient PAS de label Cassava___* dans son
      // catalogue 39-classes. Mais si jamais le futur ajoute un tel
      // label, on ne doit pas crasher : on extrait juste "Cassava".
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Cassava___healthy',
          topConfidence: 0.7,
        ),
      ]);
      expect(d.plausibleCultures, {'Cassava'});
      expect(d.supportsCulture('Cassava'), isTrue);
    });

    test('plantvillage Background top-1 mais backgroundProb null → null '
        'préfixe → unknown', () {
      // Cas où plantvillage est dans un état bizarre (Background gagne
      // sans qu'on lui assigne de backgroundProb explicite). L'extraction
      // de culture retourne null → unknown.
      final d = detector.detect(const [
        ModelEvidence(
          modelId: 'plantvillage',
          topLabel: 'Background_without_leaves',
          topConfidence: 0.9,
        ),
      ]);
      expect(d.plausibleCultures, isEmpty);
    });
  });
}
