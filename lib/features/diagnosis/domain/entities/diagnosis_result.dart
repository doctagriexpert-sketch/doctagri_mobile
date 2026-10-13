import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'diagnosis_result.g.dart';

@HiveType(typeId: 0)
class DiagnosisResult extends Equatable {
  @HiveField(0)
  final String label;

  @HiveField(1)
  final double confidence;

  @HiveField(2)
  final String imagePath;

  @HiveField(3)
  final String treatmentAdvice;

  @HiveField(4)
  final DateTime timestamp;

  // ── Nouveaux champs enrichis ──

  /// Nom lisible de la maladie (depuis la base de connaissances)
  @HiveField(5)
  final String? diseaseName;

  /// Description claire du problème pour l'agriculteur
  @HiveField(6)
  final String? diseaseDescription;

  /// Niveau de gravité: aucune, faible, modéré, grave, critique
  @HiveField(7)
  final String? severity;

  /// Si true, le score de confiance est sous le seuil — validation recommandée
  @HiveField(8)
  final bool needsValidation;

  /// Statut de validation humaine: null, pending, validated, rejected
  @HiveField(9)
  final String? validationStatus;

  /// Label brut retourné par le modèle TFLite (ex: "Tomato___Early_Blight")
  @HiveField(10)
  final String? rawModelLabel;

  /// Flag indiquant que ce diagnostic est en attente de synchronisation
  @HiveField(11)
  final bool pendingSync;

  DiagnosisResult({
    required this.label,
    required this.confidence,
    required this.imagePath,
    this.treatmentAdvice = '',
    DateTime? timestamp,
    this.diseaseName,
    this.diseaseDescription,
    this.severity,
    this.needsValidation = false,
    this.validationStatus,
    this.rawModelLabel,
    this.pendingSync = false,
  }) : timestamp = timestamp ?? DateTime.now();

  DiagnosisResult copyWith({
    String? label,
    double? confidence,
    String? imagePath,
    String? treatmentAdvice,
    DateTime? timestamp,
    String? diseaseName,
    String? diseaseDescription,
    String? severity,
    bool? needsValidation,
    String? validationStatus,
    String? rawModelLabel,
    bool? pendingSync,
  }) {
    return DiagnosisResult(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      imagePath: imagePath ?? this.imagePath,
      treatmentAdvice: treatmentAdvice ?? this.treatmentAdvice,
      timestamp: timestamp ?? this.timestamp,
      diseaseName: diseaseName ?? this.diseaseName,
      diseaseDescription: diseaseDescription ?? this.diseaseDescription,
      severity: severity ?? this.severity,
      needsValidation: needsValidation ?? this.needsValidation,
      validationStatus: validationStatus ?? this.validationStatus,
      rawModelLabel: rawModelLabel ?? this.rawModelLabel,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props => [
    label,
    confidence,
    imagePath,
    treatmentAdvice,
    timestamp,
    diseaseName,
    diseaseDescription,
    severity,
    needsValidation,
    validationStatus,
    rawModelLabel,
    pendingSync,
  ];
}
