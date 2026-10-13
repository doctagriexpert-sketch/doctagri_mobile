import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../features/diagnosis/domain/entities/disease_info.dart';
import 'supabase_service.dart';

@lazySingleton
class TranslationService {
  final SupabaseService _supabaseService;
  Box<String>? _box;

  TranslationService(this._supabaseService);

  bool get isReady => _box != null;

  Future<void> initialize() async {
    _box = await Hive.openBox<String>('nllb_translations');
  }

  String? getCached(String modelLabel, String langCode) =>
      _box?.get('${modelLabel}_$langCode');

  Future<String?> translatePlainExplanation(
    String frenchText, {
    required String modelLabel,
    required String langCode,
  }) async {
    final cached = getCached(modelLabel, langCode);
    if (cached != null) return cached;

    final nllbLang = _toNllbCode(langCode);
    if (nllbLang == null) return null;

    try {
      final translations = await _supabaseService.invokeBatchTranslate(
        texts: [frenchText],
        targetLang: nllbLang,
      );
      final result = translations?.firstOrNull;
      if (result != null && result.isNotEmpty) {
        await _box?.put('${modelLabel}_$langCode', result);
        return result;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TranslationService] Error: $e');
    }
    return null;
  }

  Future<void> prefetchAll(List<DiseaseInfo> diseases) async {
    if (!_supabaseService.isInitialized || _box == null) return;

    // Kabyè (kab) is not supported by NLLB-200 — Ewe only
    const supportedLangs = ['ee'];
    for (final langCode in supportedLangs) {
      final nllbLang = _toNllbCode(langCode);
      if (nllbLang == null) continue;

      final uncached = diseases
          .where((d) => getCached(d.modelLabel, langCode) == null)
          .toList();

      for (var i = 0; i < uncached.length; i += 5) {
        final batch = uncached.skip(i).take(5).toList();
        final texts = batch
            .map((d) => d.localizedPlainExplanation('fr'))
            .toList();

        try {
          final translations = await _supabaseService.invokeBatchTranslate(
            texts: texts,
            targetLang: nllbLang,
          );
          if (translations != null) {
            for (var j = 0; j < translations.length && j < batch.length; j++) {
              final t = translations[j];
              if (t.isNotEmpty) {
                await _box!.put('${batch[j].modelLabel}_$langCode', t);
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[TranslationService] Prefetch batch error: $e');
          }
        }
      }
    }
  }

  static String? _toNllbCode(String langCode) {
    const map = {'ee': 'ewe_Latn', 'fr': 'fra_Latn'};
    return map[langCode];
  }
}
