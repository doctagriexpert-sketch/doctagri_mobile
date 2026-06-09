import 'dart:io';
import 'package:flutter/foundation.dart';
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

class _PreprocessArgs {
  final String imagePath;
  final int inputSize;
  final List<double> mean;
  final List<double> std;

  const _PreprocessArgs(this.imagePath, this.inputSize, this.mean, this.std);
}

Future<PreprocessedImage> preprocessImage(
  String imagePath, {
  int inputSize = kModelInputSize,
  List<double> mean = kImageNetMean,
  List<double> std = kImageNetStd,
}) {
  return compute(
    _preprocessIsolate,
    _PreprocessArgs(imagePath, inputSize, mean, std),
  );
}

PreprocessedImage _preprocessIsolate(_PreprocessArgs args) {
  final file = File(args.imagePath);
  if (!file.existsSync()) {
    throw FileSystemException('Fichier introuvable', args.imagePath);
  }

  final bytes = file.readAsBytesSync();
  final imageData = img.decodeImage(bytes);
  if (imageData == null) {
    throw FormatException('Format image non supporté: ${args.imagePath}');
  }

  final size = args.inputSize;
  final resized = img.copyResize(
    imageData,
    width: size,
    height: size,
    interpolation: img.Interpolation.linear,
  );

  final totalPixels = size * size * kModelChannels;
  final uint8Pixels = Uint8List(totalPixels);
  final float32Input = Float32List(totalPixels);

  int idx = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final pixel = resized.getPixel(x, y);

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      uint8Pixels[idx] = r;
      uint8Pixels[idx + 1] = g;
      uint8Pixels[idx + 2] = b;

      float32Input[idx++] = (r - args.mean[0]) / args.std[0];
      float32Input[idx++] = (g - args.mean[1]) / args.std[1];
      float32Input[idx++] = (b - args.mean[2]) / args.std[2];
    }
  }

  return PreprocessedImage(
    float32Input: float32Input,
    uint8Pixels: uint8Pixels,
    width: size,
    height: size,
  );
}
