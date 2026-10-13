import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../domain/repositories/history_repository.dart';

@LazySingleton(as: HistoryRepository)
class HistoryRepositoryImpl implements HistoryRepository {
  static const String boxName = 'diagnosis_history';
  final Box<DiagnosisResult> _box;

  HistoryRepositoryImpl({
    @Named('diagnosisBox') required Box<DiagnosisResult> box,
  }) : _box = box;

  @override
  Future<void> saveDiagnosis(DiagnosisResult result) async {
    await _box.add(result);
  }

  @override
  Future<List<DiagnosisResult>> getHistory() async {
    // Retourner la liste inversée (plus récent en premier)
    return _box.values.toList().reversed.toList();
  }

  @override
  Future<void> clearHistory() async {
    await _box.clear();
  }

  @override
  Future<void> markSynced(String imagePath, DateTime timestamp) async {
    for (int i = 0; i < _box.length; i++) {
      final item = _box.getAt(i);
      if (item != null &&
          item.imagePath == imagePath &&
          item.timestamp == timestamp &&
          item.pendingSync) {
        await _box.putAt(i, item.copyWith(pendingSync: false));
        return;
      }
    }
  }
}
