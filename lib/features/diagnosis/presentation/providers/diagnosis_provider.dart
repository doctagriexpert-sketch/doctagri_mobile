import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../domain/entities/diagnosis_explanation.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../domain/entities/disease_info.dart';
import '../../domain/entities/validation_request.dart';
import '../../domain/repositories/diagnosis_repository.dart';
import '../../domain/repositories/disease_knowledge_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/validation_repository.dart';

enum DiagnosisStatus { initial, loading, success, error }

@injectable
class DiagnosisProvider extends ChangeNotifier {
  final DiagnosisRepository repository;
  final HistoryRepository historyRepository;
  final DiseaseKnowledgeRepository knowledgeRepository;
  final ValidationRepository validationRepository;
  final SyncService syncService;
  final VoiceService voiceService;
  final LanguageService languageService;
  final TranslationService translationService;

  DiagnosisProvider({
    required this.repository,
    required this.historyRepository,
    required this.knowledgeRepository,
    required this.validationRepository,
    required this.syncService,
    required this.voiceService,
    required this.languageService,
    required this.translationService,
  });

  static const _explanationBuilder = DiagnosisExplanationBuilder();

  DiagnosisStatus _status = DiagnosisStatus.initial;
  DiagnosisResult? _result;
  String? _errorMessage;
  DiseaseInfo? _diseaseInfo;
  DiagnosisExplanation? _explanation;
  bool _validationRequested = false;
  bool _autoSpeakEnabled = true;

  DiagnosisStatus get status => _status;
  DiagnosisResult? get result => _result;
  String? get errorMessage => _errorMessage;

  /// Informations enrichies de la maladie (depuis la base de connaissances)
  DiseaseInfo? get diseaseInfo => _diseaseInfo;

  /// Explication courte + détaillée prête pour l'affichage et le TTS,
  /// déjà localisée dans la langue active.
  DiagnosisExplanation? get explanation => _explanation;

  /// Indique si une validation humaine a été demandée pour ce diagnostic
  bool get validationRequested => _validationRequested;

  /// Le TTS automatique se déclenche-t-il à chaque diagnostic réussi ?
  bool get autoSpeakEnabled => _autoSpeakEnabled;

  /// Active / désactive le TTS auto. Persistance via Hive non gérée ici
  /// pour rester simple : la préférence est valable pour la session.
  void setAutoSpeakEnabled(bool enabled) {
    if (_autoSpeakEnabled == enabled) return;
    _autoSpeakEnabled = enabled;
    notifyListeners();
  }

  Future<void> analyzeImage(String imagePath) async {
    _status = DiagnosisStatus.loading;
    _errorMessage = null;
    _diseaseInfo = null;
    _explanation = null;
    _validationRequested = false;
    notifyListeners();

    final diagnosisEither = await repository.analyzeImage(imagePath);

    final failure = diagnosisEither.fold<Failure?>((f) => f, (_) => null);
    final diagnosis = diagnosisEither.fold<DiagnosisResult?>(
      (_) => null,
      (d) => d,
    );

    if (failure != null) {
      _status = DiagnosisStatus.error;
      _errorMessage = _mapFailureToMessage(failure);
      notifyListeners();
      return;
    }

    if (diagnosis == null) {
      _status = DiagnosisStatus.error;
      _errorMessage = 'Résultat inattendu.';
      notifyListeners();
      return;
    }

    _status = DiagnosisStatus.success;

    if (diagnosis.rawModelLabel != null) {
      _diseaseInfo = knowledgeRepository.getDiseaseByLabel(
        diagnosis.rawModelLabel!,
      );
    }

    // Apply cached NLLB Ewe translation if available (Kabyè not in NLLB-200)
    final langCode = languageService.languageCode;
    if (_diseaseInfo != null && langCode == 'ee') {
      final cached = translationService.getCached(
        _diseaseInfo!.modelLabel,
        'ee',
      );
      if (cached != null) {
        _diseaseInfo = _diseaseInfo!.withPlainExplanationOverride('ee', cached);
      }
    }

    // Construit l'explication localisée AVANT de sauvegarder, pour que
    // l'UI puisse l'afficher immédiatement et que le TTS auto démarre.
    _explanation = _explanationBuilder.build(
      result: diagnosis,
      info: _diseaseInfo,
      langCode: langCode,
    );

    await _persistAndSync(diagnosis);
    notifyListeners();

    // Lecture automatique de l'explication courte dans la langue active.
    // On utilise la version "plain" pour rester court à l'oral; le bouton
    // "Écouter en détail" reste disponible pour la version longue.
    if (_autoSpeakEnabled && _explanation != null) {
      _speakExplanation();
    }

    // Background NLLB fetch if Ewe is active and no cached translation yet
    if (_diseaseInfo != null &&
        langCode == 'ee' &&
        translationService.getCached(_diseaseInfo!.modelLabel, 'ee') == null) {
      _fetchNllbBackground(_diseaseInfo!);
    }
  }

  void _fetchNllbBackground(DiseaseInfo info) {
    // ignore: discarded_futures
    translationService
        .translatePlainExplanation(
          info.localizedPlainExplanation('fr'),
          modelLabel: info.modelLabel,
          langCode: 'ee',
        )
        .then((translated) {
          if (translated != null &&
              _diseaseInfo?.modelLabel == info.modelLabel &&
              _result != null) {
            _diseaseInfo = _diseaseInfo!.withPlainExplanationOverride(
              'ee',
              translated,
            );
            _explanation = _explanationBuilder.build(
              result: _result!,
              info: _diseaseInfo,
              langCode: languageService.languageCode,
            );
            notifyListeners();
            if (_autoSpeakEnabled && languageService.languageCode == 'ee') {
              _speakExplanation();
            }
          }
        })
        .catchError((_) {});
  }

  void _speakExplanation() {
    final text = _explanation?.plainText;
    if (text == null || text.isEmpty) return;

    voiceService.setLanguage(languageService.languageCode);
    // ignore: discarded_futures
    voiceService.speak(text);
  }

  /// Permet à l'UI de relancer la lecture vocale de l'explication
  /// courante (par exemple via un bouton "Réécouter").
  Future<void> speakPlain() async {
    if (_explanation == null) return;
    voiceService.setLanguage(languageService.languageCode);
    await voiceService.speak(_explanation!.plainText);
  }

  /// Lecture vocale de la version DÉTAILLÉE (description + symptômes +
  /// traitements + prévention), toujours dans la langue active.
  Future<void> speakDetailed() async {
    if (_explanation == null) return;
    voiceService.setLanguage(languageService.languageCode);
    await voiceService.speak(_explanation!.detailedText);
  }

  /// Logique de persistance et synchronisation extraite (SRP)
  Future<void> _persistAndSync(DiagnosisResult diagnosis) async {
    final online = await syncService.isOnline();

    if (online) {
      final synced = await syncService.syncDiagnosisNow(diagnosis);
      final resultToSave = diagnosis.copyWith(pendingSync: !synced);
      _result = resultToSave;
      await historyRepository.saveDiagnosis(resultToSave);

      if (!synced) {
        await syncService.enqueueDiagnosis(resultToSave);
        if (kDebugMode) {
          debugPrint('[DiagnosisProvider] Sync échouée → file d\'attente');
        }
      }
    } else {
      final resultToSave = diagnosis.copyWith(pendingSync: true);
      _result = resultToSave;
      await historyRepository.saveDiagnosis(resultToSave);
      await syncService.enqueueDiagnosis(resultToSave);
      if (kDebugMode) {
        debugPrint('[DiagnosisProvider] Hors-ligne → file d\'attente');
      }
    }
  }

  /// Demande une validation humaine pour le diagnostic courant.
  /// Crée un ValidationRequest et le stocke dans la queue locale.
  Future<void> requestHumanValidation() async {
    if (_result == null) return;

    final request = ValidationRequest(
      id: const Uuid().v4(),
      imagePath: _result!.imagePath,
      predictedLabel: _result!.rawModelLabel ?? _result!.label,
      confidence: _result!.confidence,
      requestedAt: DateTime.now(),
      status: 'pending',
    );

    await validationRepository.submitValidation(request);

    _result = _result!.copyWith(validationStatus: 'pending');
    _validationRequested = true;
    notifyListeners();

    if (kDebugMode) debugPrint('✅ Validation humaine demandée: ${request.id}');
  }

  void reset() {
    // Coupe la lecture vocale en cours si elle existe.
    if (voiceService.isSpeaking) {
      // ignore: discarded_futures
      voiceService.stopSpeaking();
    }
    _status = DiagnosisStatus.initial;
    _result = null;
    _errorMessage = null;
    _diseaseInfo = null;
    _explanation = null;
    _validationRequested = false;
    notifyListeners();
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is CacheFailure) return failure.message;
    if (failure is ModelFailure) return failure.message;
    if (failure is NetworkFailure) return failure.message;
    if (failure is ImageProcessingFailure) return failure.message;
    return 'Une erreur inattendue est survenue.';
  }
}
