import 'diagnosis_metadata.dart';

/// Demande de validation humaine d'un diagnostic incertain.
///
/// Stockée localement en attendant la synchronisation
/// avec le backend (quand disponible).
class ValidationRequest {
  final String id;
  final String imagePath;
  final String predictedLabel;
  final double confidence;
  final DiagnosisMetadata? metadata;
  final DateTime requestedAt;
  final String status; // pending, synced, validated, rejected

  const ValidationRequest({
    required this.id,
    required this.imagePath,
    required this.predictedLabel,
    required this.confidence,
    this.metadata,
    required this.requestedAt,
    this.status = 'pending',
  });

  ValidationRequest copyWith({String? status}) {
    return ValidationRequest(
      id: id,
      imagePath: imagePath,
      predictedLabel: predictedLabel,
      confidence: confidence,
      metadata: metadata,
      requestedAt: requestedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_path': imagePath,
      'predicted_label': predictedLabel,
      'confidence': confidence,
      'metadata': metadata?.toJson(),
      'requested_at': requestedAt.toIso8601String(),
      'status': status,
    };
  }

  factory ValidationRequest.fromJson(Map<String, dynamic> json) {
    return ValidationRequest(
      id: json['id'] as String,
      imagePath: json['image_path'] as String,
      predictedLabel: json['predicted_label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      metadata: json['metadata'] != null
          ? DiagnosisMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      status: json['status'] as String? ?? 'pending',
    );
  }
}
