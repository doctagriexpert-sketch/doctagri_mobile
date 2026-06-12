import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const int kModelInputSize = 224;
const int kModelChannels = 3;

const List<double> kImageNetMean = [123.675, 116.28, 103.53];
const List<double> kImageNetStd = [58.395, 57.12, 57.375];

class PreprocessedImage {
  final Float32List float32Input;
  final Uint8List uint8Pixels;
  final int width;
  final int height;

  const PreprocessedImage({
    required this.float32Input,
    required this.uint8Pixels,
    required this.width,
    required this.height,
  });
}

PreprocessedImage preprocessImageSync(String imagePath) {
  final file = File(imagePath);
  if (!file.existsSync()) {
    throw FileSystemException('Fichier introuvable', imagePath);
  }

  final bytes = file.readAsBytesSync();
  final imageData = img.decodeImage(bytes);
  if (imageData == null) {
    throw FormatException('Format image non supporté: $imagePath');
  }

  final resized = img.copyResize(
    imageData,
    width: kModelInputSize,
    height: kModelInputSize,
    interpolation: img.Interpolation.linear,
  );

  final totalPixels = kModelInputSize * kModelInputSize * kModelChannels;
  final uint8Pixels = Uint8List(totalPixels);
  final float32Input = Float32List(totalPixels);

  int idx = 0;
  for (int y = 0; y < kModelInputSize; y++) {
    for (int x = 0; x < kModelInputSize; x++) {
      final pixel = resized.getPixel(x, y);

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      uint8Pixels[idx] = r;
      uint8Pixels[idx + 1] = g;
      uint8Pixels[idx + 2] = b;

      float32Input[idx++] = (r - kImageNetMean[0]) / kImageNetStd[0];
      float32Input[idx++] = (g - kImageNetMean[1]) / kImageNetStd[1];
      float32Input[idx++] = (b - kImageNetMean[2]) / kImageNetStd[2];
    }
  }

  return PreprocessedImage(
    float32Input: float32Input,
    uint8Pixels: uint8Pixels,
    width: kModelInputSize,
    height: kModelInputSize,
  );
}

List<double> softmax(List<double> logits) {
  if (logits.isEmpty) return [];
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  // dart:math.exp gère correctement les grands |x| (sous-flux propre à 0
  // pour x très négatif). L'implémentation maison précédente (série de
  // Taylor 20 termes) divergeait dès |x| ~ 20 et rendait ce test faux
  // pour des cas comme softmax([100, 0, 0]) où une classe domine.
  final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
  final sumExps = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExps).toList();
}

void main() {
  group('Preprocessing', () {
    test('output tensor has correct shape [1, 224, 224, 3]', () {
      const expectedLength = 1 * 224 * 224 * 3;
      final dummyPath = 'test/fixtures/dummy_224x224.png';

      if (File(dummyPath).existsSync()) {
        final result = preprocessImageSync(dummyPath);
        expect(result.float32Input.length, expectedLength);
        expect(result.uint8Pixels.length, expectedLength);
        expect(result.width, 224);
        expect(result.height, 224);
      } else {
        markTestSkipped('Fixture dummy_224x224.png absente');
      }
    });

    test('float32Input is normalized with ImageNet mean/std', () {
      final dummyPath = 'test/fixtures/dummy_224x224.png';
      if (!File(dummyPath).existsSync()) {
        markTestSkipped('Fixture dummy_224x224.png absente');
        return;
      }

      final result = preprocessImageSync(dummyPath);

      bool allInRange = true;
      for (int i = 0; i < result.float32Input.length; i++) {
        final val = result.float32Input[i];
        if (val < -5 || val > 5) {
          allInRange = false;
          break;
        }
      }
      expect(
        allInRange,
        true,
        reason: 'Normalized values should be in reasonable range',
      );
    });

    test('uint8Pixels are clamped to 0-255', () {
      final dummyPath = 'test/fixtures/dummy_224x224.png';
      if (!File(dummyPath).existsSync()) {
        markTestSkipped('Fixture dummy_224x224.png absente');
        return;
      }

      final result = preprocessImageSync(dummyPath);
      for (int i = 0; i < result.uint8Pixels.length; i++) {
        expect(result.uint8Pixels[i], inInclusiveRange(0, 255));
      }
    });
  });

  group('Softmax', () {
    test('softmax sums to 1', () {
      final logits = [2.0, 1.0, 0.5];
      final probs = softmax(logits);
      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-6));
    });

    test('softmax is non-negative', () {
      final logits = [2.0, 1.0, 0.5];
      final probs = softmax(logits);
      for (final p in probs) {
        expect(p, greaterThanOrEqualTo(0.0));
      }
    });

    test('softmax max is ~1 when one logit dominates', () {
      // softmax dépend de l'écart entre logits, pas de leur valeur absolue.
      // Avec [100, 0, 0], le 1er domine très largement → proche de 1.
      // (À l'inverse, [100, 99, 98] donnerait ~0.665 car les écarts sont
      // faibles — c'était le bug du test précédent.)
      final logits = [100.0, 0.0, 0.0];
      final probs = softmax(logits);
      expect(probs[0], closeTo(1.0, 1e-6));
    });

    test('softmax handles empty list', () {
      final probs = softmax([]);
      expect(probs, isEmpty);
    });
  });
}
