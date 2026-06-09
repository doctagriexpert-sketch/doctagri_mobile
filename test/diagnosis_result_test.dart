import 'package:flutter_test/flutter_test.dart';
import 'package:doctagri/features/diagnosis/domain/entities/diagnosis_result.dart';

void main() {
  group('DiagnosisResult', () {
    test('copyWith pendingSync modifie uniquement le flag', () {
      final result = DiagnosisResult(
        label: 'Mildiou',
        confidence: 0.92,
        imagePath: '/tmp/img.jpg',
        rawModelLabel: 'Tomato___Late_Blight',
        pendingSync: false,
      );

      final offline = result.copyWith(pendingSync: true);

      expect(offline.pendingSync, true);
      expect(offline.label, 'Mildiou');
      expect(offline.confidence, 0.92);
      expect(offline.rawModelLabel, 'Tomato___Late_Blight');
    });

    test('pendingSync est false par défaut', () {
      final result = DiagnosisResult(
        label: 'Sain',
        confidence: 0.99,
        imagePath: '/tmp/healthy.jpg',
      );

      expect(result.pendingSync, false);
    });

    test('Equatable inclut pendingSync dans props', () {
      final a = DiagnosisResult(
        label: 'Test',
        confidence: 0.5,
        imagePath: '/tmp/a.jpg',
        pendingSync: false,
      );
      final b = DiagnosisResult(
        label: 'Test',
        confidence: 0.5,
        imagePath: '/tmp/a.jpg',
        pendingSync: true,
      );

      expect(a == b, false);
      expect(a.props.contains(false), true);
      expect(b.props.contains(true), true);
    });

    test('timestamp est défini par défaut à DateTime.now()', () {
      final before = DateTime.now();
      final result = DiagnosisResult(
        label: 'Test',
        confidence: 0.5,
        imagePath: '/tmp/test.jpg',
      );
      final after = DateTime.now();

      expect(
        result.timestamp.isAfter(before) ||
            result.timestamp.isAtSameMomentAs(before),
        true,
      );
      expect(
        result.timestamp.isBefore(after) ||
            result.timestamp.isAtSameMomentAs(after),
        true,
      );
    });

    test('needsValidation est false par défaut', () {
      final result = DiagnosisResult(
        label: 'Test',
        confidence: 0.8,
        imagePath: '/tmp/test.jpg',
      );

      expect(result.needsValidation, false);
    });

    test('copyWith préserve toutes les valeurs non spécifiées', () {
      final original = DiagnosisResult(
        label: 'CBD',
        confidence: 0.75,
        imagePath: '/tmp/cassava.jpg',
        treatmentAdvice: 'Appliquer du cuivre',
        diseaseName: 'Brûlure bactérienne',
        diseaseDescription: 'Maladie bactérienne du manioc',
        severity: 'critique',
        needsValidation: false,
        rawModelLabel: 'Cassava Bacterial Blight (CBB)',
        pendingSync: true,
      );

      final copy = original.copyWith(confidence: 0.90);

      expect(copy.confidence, 0.90);
      expect(copy.label, 'CBD');
      expect(copy.imagePath, '/tmp/cassava.jpg');
      expect(copy.treatmentAdvice, 'Appliquer du cuivre');
      expect(copy.diseaseName, 'Brûlure bactérienne');
      expect(copy.severity, 'critique');
      expect(copy.pendingSync, true);
    });

    test('deux instances identiques sont égales', () {
      final now = DateTime.now();
      final a = DiagnosisResult(
        label: 'Cassava___healthy',
        confidence: 0.95,
        imagePath: '/tmp/h.jpg',
        timestamp: now,
      );
      final b = DiagnosisResult(
        label: 'Cassava___healthy',
        confidence: 0.95,
        imagePath: '/tmp/h.jpg',
        timestamp: now,
      );

      expect(a, equals(b));
    });
  });
}
