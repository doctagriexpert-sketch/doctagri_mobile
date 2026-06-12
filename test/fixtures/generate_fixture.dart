// Génère la fixture `dummy_224x224.png` utilisée par
// `test/unit/core/preprocessing_test.dart`.
//
// À relancer uniquement si la fixture est supprimée :
//   dart run test/fixtures/generate_fixture.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 224, height: 224);
  // Dégradé déterministe couvrant toute la plage 0-255 sur les 3 canaux,
  // pour que les tests de normalisation exercent des valeurs variées.
  for (int y = 0; y < 224; y++) {
    for (int x = 0; x < 224; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  final out = File('test/fixtures/dummy_224x224.png');
  out.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Fixture écrite: ${out.path}');
}
