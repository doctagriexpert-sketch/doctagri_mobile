import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/diagnosis/domain/entities/diagnosis_result.dart';

@lazySingleton
class SupabaseService {
  SupabaseClient? _client;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isAuthenticated =>
      _client?.auth.currentSession != null &&
      _client!.auth.currentUser?.isAnonymous == false;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<bool> initialize() async {
    if (_initialized) return true;

    final url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final anonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    if (url.isEmpty || anonKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SupabaseService] Clés manquantes — sync désactivée');
      }
      return false;
    }

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
      _initialized = true;

      if (kDebugMode) {
        debugPrint('[SupabaseService] Initialisé (auth requise pour sync)');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseService] Erreur init: $e');
      }
      return false;
    }
  }

  // ── AUTH : OTP par téléphone (adapté marché africain) ──

  /// Envoie un OTP par SMS au numéro donné.
  Future<bool> sendOtp(String phoneNumber) async {
    if (_client == null) return false;
    try {
      await _client!.auth.signInWithOtp(phone: phoneNumber);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseService] Erreur envoi OTP: $e');
      return false;
    }
  }

  /// Vérifie l'OTP saisi par l'utilisateur.
  Future<bool> verifyOtp(String phoneNumber, String token) async {
    if (_client == null) return false;
    try {
      final response = await _client!.auth.verifyOTP(
        type: OtpType.sms,
        phone: phoneNumber,
        token: token,
      );
      return response.session != null;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseService] Erreur verify OTP: $e');
      return false;
    }
  }

  /// Déconnexion.
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  // ── STORAGE : bucket privé + isolation par user ──

  Future<String?> uploadImage(String localPath) async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('[SupabaseService] Fichier introuvable: $localPath');
        }
        return null;
      }

      final userId = currentUserId!;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${localPath.split(Platform.pathSeparator).last}';
      final storagePath = '$userId/diagnoses/$fileName';

      await _client!.storage.from('diagnosis-images').upload(storagePath, file);

      if (kDebugMode) {
        debugPrint('[SupabaseService] Image uploadée: $storagePath');
      }
      return storagePath;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseService] Erreur upload: $e');
      return null;
    }
  }

  /// Calls the `translate` Edge Function with a batch of texts.
  /// Returns the translated strings in the same order, or null on error.
  Future<List<String>?> invokeBatchTranslate({
    required List<String> texts,
    required String targetLang,
    String sourceLang = 'fra_Latn',
  }) async {
    if (_client == null) return null;
    try {
      final result = await _client!.functions.invoke(
        'translate',
        body: {
          'texts': texts,
          'targetLang': targetLang,
          'sourceLang': sourceLang,
        },
      );
      final data = result.data as Map<String, dynamic>?;
      final raw = data?['translations'] as List<dynamic>?;
      return raw?.map((e) => e.toString()).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseService] invokeBatchTranslate error: $e');
      }
      return null;
    }
  }

  Future<bool> insertDiagnosisRecord(
    DiagnosisResult result,
    String remoteImagePath,
  ) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      // ── Signed URL (expire dans 1h) au lieu de public URL ──
      await _client!.storage
          .from('diagnosis-images')
          .createSignedUrl(remoteImagePath, 3600);

      await _client!.from('diagnoses').insert({
        'user_id': currentUserId, // ← RLS : isolation par user
        'label': result.label,
        'raw_model_label': result.rawModelLabel,
        'confidence': result.confidence,
        'image_path': remoteImagePath, // ← Stocker le path, pas l'URL
        'treatment_advice': result.treatmentAdvice,
        'disease_name': result.diseaseName,
        'severity': result.severity,
        'needs_validation': result.needsValidation,
        'validation_status': result.validationStatus,
        'created_at': result.timestamp.toIso8601String(),
      });

      if (kDebugMode) debugPrint('[SupabaseService] Diagnostic inséré en base');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseService] Erreur insertion: $e');
      return false;
    }
  }
}
