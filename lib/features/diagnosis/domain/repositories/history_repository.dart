import '../entities/diagnosis_result.dart';

abstract class HistoryRepository {
  Future<void> saveDiagnosis(DiagnosisResult result);
  Future<List<DiagnosisResult>> getHistory();
  Future<void> clearHistory();

  /// Marque un diagnostic comme synchronisé (pendingSync = false).
  Future<void> markSynced(String imagePath, DateTime timestamp);
}
