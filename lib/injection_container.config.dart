// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:hive/hive.dart' as _i979;
import 'package:injectable/injectable.dart' as _i526;

import 'core/di/register_module.dart' as _i854;
import 'core/services/language_service.dart' as _i903;
import 'core/services/supabase_service.dart' as _i978;
import 'core/services/sync_queue.dart' as _i588;
import 'core/services/sync_service.dart' as _i443;
import 'core/services/translation_service.dart' as _i64;
import 'core/services/voice_service.dart' as _i64;
import 'features/diagnosis/data/repositories/diagnosis_repository_impl.dart'
    as _i495;
import 'features/diagnosis/data/repositories/disease_knowledge_repository_impl.dart'
    as _i186;
import 'features/diagnosis/data/repositories/history_repository_impl.dart'
    as _i108;
import 'features/diagnosis/data/repositories/validation_repository_impl.dart'
    as _i131;
import 'features/diagnosis/domain/entities/diagnosis_result.dart' as _i691;
import 'features/diagnosis/domain/repositories/diagnosis_repository.dart'
    as _i323;
import 'features/diagnosis/domain/repositories/disease_knowledge_repository.dart'
    as _i381;
import 'features/diagnosis/domain/repositories/history_repository.dart'
    as _i256;
import 'features/diagnosis/domain/repositories/validation_repository.dart'
    as _i915;
import 'features/diagnosis/presentation/providers/diagnosis_provider.dart'
    as _i249;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i903.LanguageService>(() => _i903.LanguageService());
    gh.lazySingleton<_i978.SupabaseService>(() => _i978.SupabaseService());
    gh.lazySingleton<_i64.VoiceService>(() => _i64.VoiceService());
    await gh.factoryAsync<_i979.Box<String>>(
      () => registerModule.validationBox,
      instanceName: 'validationBox',
      preResolve: true,
    );
    await gh.factoryAsync<_i979.Box<String>>(
      () => registerModule.syncBox,
      instanceName: 'syncBox',
      preResolve: true,
    );
    gh.lazySingleton<_i381.DiseaseKnowledgeRepository>(
        () => _i186.DiseaseKnowledgeRepositoryImpl());
    await gh.factoryAsync<_i979.Box<_i691.DiagnosisResult>>(
      () => registerModule.diagnosisBox,
      instanceName: 'diagnosisBox',
      preResolve: true,
    );
    gh.lazySingleton<_i256.HistoryRepository>(() => _i108.HistoryRepositoryImpl(
        box: gh<_i979.Box<_i691.DiagnosisResult>>(
            instanceName: 'diagnosisBox')));
    gh.lazySingleton<_i323.DiagnosisRepository>(() =>
        _i495.DiagnosisRepositoryImpl(
            knowledgeRepository: gh<_i381.DiseaseKnowledgeRepository>()));
    gh.lazySingleton<_i588.SyncQueue>(() =>
        _i588.SyncQueue(box: gh<_i979.Box<String>>(instanceName: 'syncBox')));
    gh.lazySingleton<_i64.TranslationService>(
        () => _i64.TranslationService(gh<_i978.SupabaseService>()));
    gh.lazySingleton<_i915.ValidationRepository>(() =>
        _i131.ValidationRepositoryImpl(
            box: gh<_i979.Box<String>>(instanceName: 'validationBox')));
    gh.lazySingleton<_i443.SyncService>(() => _i443.SyncService(
          syncQueue: gh<_i588.SyncQueue>(),
          supabaseService: gh<_i978.SupabaseService>(),
          historyRepository: gh<_i256.HistoryRepository>(),
        ));
    gh.factory<_i249.DiagnosisProvider>(() => _i249.DiagnosisProvider(
          repository: gh<_i323.DiagnosisRepository>(),
          historyRepository: gh<_i256.HistoryRepository>(),
          knowledgeRepository: gh<_i381.DiseaseKnowledgeRepository>(),
          validationRepository: gh<_i915.ValidationRepository>(),
          syncService: gh<_i443.SyncService>(),
          voiceService: gh<_i64.VoiceService>(),
          languageService: gh<_i903.LanguageService>(),
          translationService: gh<_i64.TranslationService>(),
        ));
    return this;
  }
}

class _$RegisterModule extends _i854.RegisterModule {}
