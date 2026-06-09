import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../features/diagnosis/domain/entities/diagnosis_result.dart';
import '../../features/diagnosis/domain/repositories/history_repository.dart';
import 'supabase_service.dart';
import 'sync_queue.dart';

const int kMaxRetryCount = 5;
const Duration kSyncTimeout = Duration(seconds: 30);

/// Orchestrateur de synchronisation offline-first.
///
/// Écoute les changements de connectivité et synchronise
/// automatiquement les diagnostics en attente vers Supabase.
@lazySingleton
class SyncService {
  final SyncQueue _syncQueue;
  final SupabaseService _supabaseService;
  final HistoryRepository _historyRepository;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Completer<void>? _syncLock; // ← Remplace bool _isSyncing

  SyncService({
    required SyncQueue syncQueue,
    required SupabaseService supabaseService,
    required HistoryRepository historyRepository,
  }) : _syncQueue = syncQueue,
       _supabaseService = supabaseService,
       _historyRepository = historyRepository;

  /// Démarre l'écoute des changements de connectivité.
  void startListening() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);

      if (hasConnection) {
        if (kDebugMode) {
          debugPrint('[SyncService] Connexion détectée — lancement sync');
        }
        processQueue();
      }
    });

    if (kDebugMode) {
      debugPrint('[SyncService] Écoute connectivité démarrée');
    }
  }

  /// Vérifie si le réseau est actuellement disponible.
  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  /// Enregistre un diagnostic dans la file d'attente pour synchronisation.
  Future<void> enqueueDiagnosis(DiagnosisResult result) async {
    final syncItem = SyncItem(
      type: 'diagnosis',
      data: {
        'label': result.label,
        'raw_model_label': result.rawModelLabel,
        'confidence': result.confidence,
        'treatment_advice': result.treatmentAdvice,
        'disease_name': result.diseaseName,
        'severity': result.severity,
        'needs_validation': result.needsValidation,
        'validation_status': result.validationStatus,
        'timestamp': result.timestamp.toIso8601String(),
      },
      imagePath: result.imagePath,
    );

    await _syncQueue.enqueue(syncItem);
    if (kDebugMode) {
      debugPrint(
        '[SyncService] Diagnostic mis en file d\'attente: ${syncItem.id}',
      );
    }
  }

  /// Tente de synchroniser un diagnostic immédiatement (quand en ligne).
  ///
  /// Retourne true si l'upload a réussi.
  Future<bool> syncDiagnosisNow(DiagnosisResult result) async {
    if (!_supabaseService.isInitialized) return false;

    try {
      final remotePath = await _supabaseService.uploadImage(result.imagePath);
      if (remotePath == null) return false;

      final inserted = await _supabaseService.insertDiagnosisRecord(
        result,
        remotePath,
      );

      if (inserted) {
        if (kDebugMode) debugPrint('[SyncService] Sync immédiate réussie');
      }
      return inserted;
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncService] Sync immédiate échouée: $e');
      return false;
    }
  }

  /// Traite tous les items en attente dans la SyncQueue.
  /// Mutex via Completer : un seul processQueue() actif à la fois.
  Future<void> processQueue() async {
    // ── Mutex : si sync en cours, ne pas doubler ──
    if (_syncLock != null && !_syncLock!.isCompleted) {
      if (kDebugMode) {
        debugPrint('[SyncService] Sync déjà en cours, skip');
      }
      return;
    }
    if (!_supabaseService.isInitialized) {
      if (kDebugMode) {
        debugPrint('[SyncService] Supabase non initialisé, skip');
      }
      return;
    }

    _syncLock = Completer<void>();

    try {
      final pendingItems = await _syncQueue.getPending();

      if (pendingItems.isEmpty) {
        if (kDebugMode) {
          debugPrint('[SyncService] Aucun item en attente');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[SyncService] ${pendingItems.length} item(s) à synchroniser',
        );
      }

      for (final item in pendingItems) {
        // ── Skip items ayant dépassé le max de retries ──
        if (item.retryCount >= kMaxRetryCount) {
          if (kDebugMode) {
            debugPrint(
              '[SyncService] Item ${item.id} abandonné '
              '(${item.retryCount} retries)',
            );
          }
          await _syncQueue.markPermanentlyFailed(item.id);
          continue;
        }

        if (item.type == 'diagnosis') {
          // ── Timeout par item pour éviter un blocage infini ──
          try {
            await _syncDiagnosisItem(item).timeout(kSyncTimeout);
          } on TimeoutException {
            if (kDebugMode) {
              debugPrint('[SyncService] Timeout sync item ${item.id}');
            }
            await _syncQueue.markFailed(item.id);
          }
        }
      }

      // Nettoyer les items terminés anciens
      await _syncQueue.cleanup();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Erreur traitement queue: $e');
      }
    } finally {
      // ── Toujours libérer le lock, même si exception ──
      _syncLock!.complete();
    }
  }

  Future<void> _syncDiagnosisItem(SyncItem item) async {
    try {
      // 1. Upload de l'image
      final imagePath = item.imagePath;
      if (imagePath == null) {
        if (kDebugMode) {
          debugPrint('[SyncService] Pas d\'image pour ${item.id}, skip');
        }
        await _syncQueue.markFailed(item.id);
        return;
      }

      final remotePath = await _supabaseService.uploadImage(imagePath);
      if (remotePath == null) {
        if (kDebugMode) {
          debugPrint('[SyncService] Upload échoué pour ${item.id}');
        }
        await _syncQueue.markFailed(item.id);
        return;
      }

      // 2. Reconstruire le DiagnosisResult depuis les données du SyncItem
      final data = item.data;
      final result = DiagnosisResult(
        label: data['label'] as String? ?? '',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
        imagePath: imagePath,
        treatmentAdvice: data['treatment_advice'] as String? ?? '',
        timestamp: data['timestamp'] != null
            ? DateTime.parse(data['timestamp'] as String)
            : item.createdAt,
        diseaseName: data['disease_name'] as String?,
        severity: data['severity'] as String?,
        needsValidation: data['needs_validation'] as bool? ?? false,
        validationStatus: data['validation_status'] as String?,
        rawModelLabel: data['raw_model_label'] as String?,
      );

      // 3. Insérer dans la table Supabase
      final inserted = await _supabaseService.insertDiagnosisRecord(
        result,
        remotePath,
      );

      if (inserted) {
        await _syncQueue.markCompleted(item.id);

        // 4. Mettre à jour le flag pendingSync dans l'historique local
        await _historyRepository.markSynced(imagePath, result.timestamp);

        if (kDebugMode) {
          debugPrint('[SyncService] Item ${item.id} synchronisé avec succès');
        }
      } else {
        await _syncQueue.markFailed(item.id);
        if (kDebugMode) {
          debugPrint('[SyncService] Insertion échouée pour ${item.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Erreur sync item ${item.id}: $e');
      }
      await _syncQueue.markFailed(item.id);
    }
  }

  /// Retourne le nombre de diagnostics en attente de synchronisation.
  Future<int> get pendingCount => _syncQueue.pendingCount;

  /// Arrête l'écoute de connectivité.
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (kDebugMode) debugPrint('[SyncService] Écoute connectivité arrêtée');
  }
}
