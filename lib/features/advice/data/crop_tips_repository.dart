import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/entities/crop_tip.dart';

/// Repository chargeant les conseils par culture depuis les assets.
///
/// Chargement lazy : le JSON n'est parsé qu'à la première demande, puis mis
/// en cache en mémoire. Léger et sans dépendance réseau — idéal hors ligne.
class CropTipsRepository {
  static const String _assetPath = 'assets/data/crop_tips.json';

  List<Crop>? _cache;

  Future<List<Crop>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => Crop.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
  }

  Future<Crop?> findById(String cropId) async {
    final crops = await loadAll();
    for (final c in crops) {
      if (c.cropId == cropId) return c;
    }
    return null;
  }
}
