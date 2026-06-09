import 'package:flutter_test/flutter_test.dart';

import 'package:doctagri/features/diagnosis/data/repositories/diagnosis_repository_impl.dart';

/// Tests unitaires de la règle pure de rejet "image inutilisable"
/// basée sur la probabilité de la classe `Background_without_leaves`
/// (QW4).
///
/// Idée : aujourd'hui on ne rejette l'image que si Background est le
/// top-1 du modèle gagnant. Or un modèle peut sortir Background à 35%
/// pendant qu'une maladie ressort à 40% — le diagnostic est très
/// fragile. QW4 introduit un seuil : à partir de 25% de Background,
/// on préfère redemander une photo plutôt que diagnostiquer du bruit.
void main() {
  group('shouldRejectAsBackground', () {
    test('probabilité nulle → false', () {
      expect(shouldRejectAsBackground(0.0), isFalse);
    });

    test('probabilité au seuil exact (0.25) → false', () {
      // Le seuil est strict (> kBackgroundRejectThreshold), donc 0.25
      // pile n'est PAS sous le seuil → on diagnostique normalement.
      expect(shouldRejectAsBackground(0.25), isFalse);
    });

    test('probabilité juste au-dessus du seuil (0.26) → true', () {
      // Premier cas où QW4 déclenche.
      expect(shouldRejectAsBackground(0.26), isTrue);
    });

    test('probabilité élevée (0.50) → true', () {
      expect(shouldRejectAsBackground(0.50), isTrue);
    });

    test('probabilité quasi-certaine (0.99) → true', () {
      expect(shouldRejectAsBackground(0.99), isTrue);
    });

    test('constante de seuil exposée vaut 0.25', () {
      expect(kBackgroundRejectThreshold, equals(0.25));
    });
  });

  group('isBackgroundLabel', () {
    test('label PlantVillage exact → true', () {
      expect(isBackgroundLabel('Background_without_leaves'), isTrue);
    });

    test('label tout en minuscules → true (insensible à la casse)', () {
      expect(isBackgroundLabel('background_without_leaves'), isTrue);
    });

    test('label tout en majuscules → true', () {
      expect(isBackgroundLabel('BACKGROUND_WITHOUT_LEAVES'), isTrue);
    });

    test('label avec espaces au lieu d\'underscores → true', () {
      // Le pattern matcher est tolérant aux variantes de séparateurs.
      expect(isBackgroundLabel('Background without leaves'), isTrue);
    });

    test('label de maladie réelle → false', () {
      expect(isBackgroundLabel('Tomato___Early_blight'), isFalse);
    });

    test('label cassava → false', () {
      expect(isBackgroundLabel('Cassava___healthy'), isFalse);
      expect(isBackgroundLabel('Cassava Bacterial Blight (CBB)'), isFalse);
    });

    test('chaîne vide → false', () {
      expect(isBackgroundLabel(''), isFalse);
    });

    test('mot isolé "background" sans le reste → false', () {
      // Le check exige les 3 mots-clés présents pour éviter les faux
      // positifs sur d'éventuels labels futurs contenant juste
      // "background".
      expect(isBackgroundLabel('background_noise'), isFalse);
      expect(isBackgroundLabel('Background_color'), isFalse);
    });
  });
}
