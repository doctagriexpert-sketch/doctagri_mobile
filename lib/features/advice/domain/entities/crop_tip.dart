/// Entité représentant un conseil agricole pour une culture donnée.
///
/// Les champs multilingues ([title], [audioText]) sont stockés comme des
/// maps `langCode → texte`. Le code langue utilisé suit [LanguageService]
/// (fr / ee / kab).
class CropTip {
  final Map<String, String> title;
  final Map<String, String> audioText;
  final String videoUrl;

  const CropTip({
    required this.title,
    required this.audioText,
    required this.videoUrl,
  });

  factory CropTip.fromJson(Map<String, dynamic> json) {
    return CropTip(
      title: _asStringMap(json['title']),
      audioText: _asStringMap(json['audioText']),
      videoUrl: json['videoUrl'] as String? ?? '',
    );
  }

  /// Retourne le titre dans la langue demandée avec fallback FR.
  String titleFor(String langCode) =>
      title[langCode] ?? title['fr'] ?? title.values.first;

  /// Retourne le texte audio dans la langue demandée avec fallback FR.
  String audioTextFor(String langCode) =>
      audioText[langCode] ?? audioText['fr'] ?? audioText.values.first;

  bool get hasVideo => videoUrl.trim().isNotEmpty;
}

/// Culture agricole regroupant une liste de conseils.
class Crop {
  final String cropId;
  final String emoji;
  final Map<String, String> name;
  final List<CropTip> tips;

  const Crop({
    required this.cropId,
    required this.emoji,
    required this.name,
    required this.tips,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      cropId: json['cropId'] as String,
      emoji: json['emoji'] as String? ?? '🌱',
      name: _asStringMap(json['name']),
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => CropTip.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Retourne le nom localisé avec fallback FR.
  String nameFor(String langCode) =>
      name[langCode] ?? name['fr'] ?? name.values.first;
}

Map<String, String> _asStringMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}
