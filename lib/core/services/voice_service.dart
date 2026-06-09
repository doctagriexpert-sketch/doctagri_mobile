import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, processing, speaking, error }

@lazySingleton
class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  String _currentLanguage = 'fr';
  String? _errorMessage;
  double _confidence = 0.0;

  // Audio level for visual feedback
  double _audioLevel = 0.0;
  Timer? _audioLevelTimer;

  VoiceState get state => _state;
  String get recognizedText => _recognizedText;
  String get currentLanguage => _currentLanguage;
  String? get errorMessage => _errorMessage;
  double get confidence => _confidence;
  double get audioLevel => _audioLevel;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;

  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (available) {
        await _configureTts();
      }

      return available;
    } catch (e) {
      _errorMessage = 'Erreur d\'initialisation vocale: $e';
      _state = VoiceState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> _configureTts() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);

    _tts.setCompletionHandler(() {
      _state = VoiceState.idle;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _errorMessage = msg;
      _state = VoiceState.error;
      notifyListeners();
    });
  }

  void setLanguage(String langCode) {
    _currentLanguage = langCode;

    final sttLocale = switch (langCode) {
      'fr' => 'fr-FR',
      'ee' => 'fr-TG',
      'kab' => 'fr-TG',
      _ => 'fr-FR',
    };

    _tts.setLanguage(sttLocale);
  }

  Future<void> startListening({Function(String)? onResult}) async {
    if (_state == VoiceState.listening) return;

    _recognizedText = '';
    _errorMessage = null;
    _state = VoiceState.listening;
    notifyListeners();

    final sttLocale = switch (_currentLanguage) {
      'fr' => 'fr_FR',
      'ee' => 'fr_TG',
      'kab' => 'fr_TG',
      _ => 'fr_FR',
    };

    await _speech.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        _confidence = result.confidence;
        if (result.finalResult) {
          _state = VoiceState.processing;
          onResult?.call(_recognizedText);
        }
        notifyListeners();
      },
      localeId: sttLocale,
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
      partialResults: true,
    );

    _startAudioLevelSimulation();
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _audioLevelTimer?.cancel();
    _audioLevel = 0.0;
    if (_state == VoiceState.listening) {
      _state = VoiceState.idle;
    }
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    _state = VoiceState.speaking;
    notifyListeners();

    String processedText = _processTextForTts(text);
    await _tts.speak(processedText);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  String _processTextForTts(String text) {
    if (_currentLanguage == 'ee' || _currentLanguage == 'kab') {
      return text
          .replaceAll('ɛ', 'e')
          .replaceAll('ŋ', 'ng')
          .replaceAll('ɔ', 'o')
          .replaceAll('ɖ', 'd')
          .replaceAll('ƒ', 'f');
    }
    return text;
  }

  void _onSpeechStatus(String status) {
    if (kDebugMode) debugPrint('[VoiceService] STT Status: $status');
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceState.listening) {
        _state = VoiceState.idle;
        _audioLevelTimer?.cancel();
        _audioLevel = 0.0;
        notifyListeners();
      }
    }
  }

  void _onSpeechError(dynamic error) {
    if (kDebugMode) debugPrint('[VoiceService] STT Error: $error');
    _errorMessage = error.toString();
    _state = VoiceState.error;
    _audioLevelTimer?.cancel();
    _audioLevel = 0.0;
    notifyListeners();
  }

  void _startAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_state != VoiceState.listening) {
        timer.cancel();
        return;
      }
      _audioLevel = (0.3 + (DateTime.now().millisecond % 7) / 10).clamp(
        0.0,
        1.0,
      );
      notifyListeners();
    });
  }

  void resetError() {
    _errorMessage = null;
    if (_state == VoiceState.error) {
      _state = VoiceState.idle;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _audioLevelTimer?.cancel();
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }
}
