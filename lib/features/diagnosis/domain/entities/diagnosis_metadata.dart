/// Métadonnées automatiques collectées lors de la prise de photo.
///
/// Ces données enrichissent le diagnostic et permettent
/// l'analyse géographique et contextuelle future.
class DiagnosisMetadata {
  final double? latitude;
  final double? longitude;
  final DateTime captureDate;
  final String? deviceModel;
  final String appVersion;
  final String? selectedCulture;

  const DiagnosisMetadata({
    this.latitude,
    this.longitude,
    required this.captureDate,
    this.deviceModel,
    this.appVersion = '1.0.0',
    this.selectedCulture,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'capture_date': captureDate.toIso8601String(),
      'device_model': deviceModel,
      'app_version': appVersion,
      'selected_culture': selectedCulture,
    };
  }

  factory DiagnosisMetadata.fromJson(Map<String, dynamic> json) {
    return DiagnosisMetadata(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      captureDate: DateTime.parse(json['capture_date'] as String),
      deviceModel: json['device_model'] as String?,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      selectedCulture: json['selected_culture'] as String?,
    );
  }
}
