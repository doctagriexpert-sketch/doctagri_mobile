import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';

class ModelManifest {
  final String version;
  final String sha256;
  final double accuracy;
  final List<double> mean;
  final List<double> std;
  final List<String> labels;
  final DateTime releasedAt;
  final String minAppVersion;

  const ModelManifest({
    required this.version,
    required this.sha256,
    required this.accuracy,
    required this.mean,
    required this.std,
    required this.labels,
    required this.releasedAt,
    required this.minAppVersion,
  });

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    return ModelManifest(
      version: json['version'] as String,
      sha256: json['sha256'] as String,
      accuracy: (json['accuracy'] as num).toDouble(),
      mean: (json['mean'] as List).map((e) => (e as num).toDouble()).toList(),
      std: (json['std'] as List).map((e) => (e as num).toDouble()).toList(),
      labels: (json['labels'] as List).map((e) => e as String).toList(),
      releasedAt: DateTime.parse(json['released_at'] as String),
      minAppVersion: json['min_app_version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'sha256': sha256,
    'accuracy': accuracy,
    'mean': mean,
    'std': std,
    'labels': labels,
    'released_at': releasedAt.toIso8601String(),
    'min_app_version': minAppVersion,
  };

  bool verifySignature(Uint8List modelBytes) {
    final computedHash = crypto.sha256.convert(modelBytes).toString();
    return computedHash == sha256;
  }
}

class ModelRegistry {
  static const String _registryAsset = 'assets/models/registry.json';

  final List<ModelManifest> _versions = [];
  String? _activeVersion;

  Future<void> load() async {
    try {
      final jsonString = await rootBundle.loadString(_registryAsset);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _versions.clear();
      _versions.addAll(
        jsonList.map((e) => ModelManifest.fromJson(e as Map<String, dynamic>)),
      );
      _activeVersion = _versions
          .firstWhere(
            (v) =>
                v.minAppVersion ==
                _versions
                    .map((e) => e.minAppVersion)
                    .reduce((a, b) => a.compareTo(b) < 0 ? a : b),
            orElse: () => _versions.last,
          )
          .version;
    } catch (e) {
      _versions.clear();
      _activeVersion = null;
    }
  }

  ModelManifest? getActive() {
    if (_activeVersion == null) return null;
    return _versions.firstWhere(
      (v) => v.version == _activeVersion,
      orElse: () => _versions.last,
    );
  }

  Future<bool> downloadModel(String version) async {
    // TODO: Implement Supabase Storage download with progress
    return true;
  }

  Future<bool> rollback(String version) async {
    // TODO: Set active version via feature flag flip
    _activeVersion = version;
    return true;
  }
}
