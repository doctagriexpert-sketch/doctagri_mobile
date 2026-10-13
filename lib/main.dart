import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'injection_container.dart' as di;
import 'core/ml/model_manager.dart';
import 'core/services/supabase_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/translation_service.dart';
import 'core/services/voice_service.dart';
import 'core/services/language_service.dart';
import 'core/services/installation_registration_service.dart';
import 'features/diagnosis/presentation/providers/diagnosis_provider.dart';
import 'features/diagnosis/domain/entities/diagnosis_result.dart';
import 'features/diagnosis/domain/repositories/disease_knowledge_repository.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(InstallationRegistrationService.initialize());

    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      // TODO Phase 3 : Sentry/Crashlytics
    };

    // ── Chemin critique : uniquement ce qui est nécessaire AVANT l'UI ──
    final sw = Stopwatch()..start();

    await Hive.initFlutter();
    Hive.registerAdapter(DiagnosisResultAdapter());
    await di.configureDependencies();

    final languageService = di.sl<LanguageService>();
    await languageService.initialize();

    final voiceService = di.sl<VoiceService>();

    if (kDebugMode) {
      debugPrint('⚡ UI prête en ${sw.elapsedMilliseconds} ms');
    }

    // ── Afficher l'app immédiatement ──
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: voiceService),
          ChangeNotifierProvider.value(value: languageService),
          ChangeNotifierProvider(create: (_) => di.sl<DiagnosisProvider>()),
        ],
        child: const DoctAgriApp(),
      ),
    );

    // ── Tout le reste en arrière-plan (ne bloque plus l'UI) ──
    unawaited(_initBackground(languageService, voiceService));
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('UNCAUGHT ERROR: $error\n$stack');
    }
    // TODO Phase 3 : Sentry/Crashlytics
  });
}

/// Initialisation différée — s'exécute pendant que l'utilisateur
/// voit déjà l'écran d'accueil. Ne bloque jamais l'UI.
Future<void> _initBackground(
  LanguageService languageService,
  VoiceService voiceService,
) async {
  final knowledgeRepo = di.sl<DiseaseKnowledgeRepository>();

  // Services indépendants en parallèle :
  //   • VoiceService (speech_to_text ~1 s sur Android)
  //   • Base de connaissances (lecture JSON assets)
  //   • Modèles TFLite (déjà parallélisés en interne)
  await Future.wait([
    voiceService.initialize().then((_) {
      voiceService.setLanguage(languageService.languageCode);
    }),
    knowledgeRepo.initialize(),
    ModelManager.instance.initialize(),
  ]);

  if (!knowledgeRepo.isReady && kDebugMode) {
    debugPrint('⚠️ Base de connaissances non chargée');
  }
  if (!ModelManager.instance.isReady && kDebugMode) {
    debugPrint(
      '⚠️ Modèle ML non chargé : ${ModelManager.instance.error}',
    );
  }

  // Supabase (réseau) — après le reste pour ne pas ralentir les assets
  final supabaseService = di.sl<SupabaseService>();
  final supabaseReady = await supabaseService.initialize();

  final syncService = di.sl<SyncService>();
  syncService.startListening();
  if (supabaseReady) {
    unawaited(syncService.processQueue());
  }

  // Traductions NLLB (dépend de Supabase + base de connaissances)
  final translationService = di.sl<TranslationService>();
  await translationService.initialize();
  if (supabaseReady && knowledgeRepo.isReady) {
    unawaited(translationService.prefetchAll(knowledgeRepo.getAllDiseases()));
  }

  if (kDebugMode) debugPrint('✅ Background init terminé');
}
