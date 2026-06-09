import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

/// Élément de la file d'attente de synchronisation.
class SyncItem {
  final String id;
  final String type; // 'image', 'validation', 'diagnosis'
  final Map<String, dynamic> data;
  final String? imagePath;
  final DateTime createdAt;
  final String status; // 'pending', 'syncing', 'completed', 'failed'
  final int retryCount;

  SyncItem({
    String? id,
    required this.type,
    required this.data,
    this.imagePath,
    DateTime? createdAt,
    this.status = 'pending',
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  SyncItem copyWith({String? status, int? retryCount}) {
    return SyncItem(
      id: id,
      type: type,
      data: data,
      imagePath: imagePath,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'image_path': imagePath,
    'created_at': createdAt.toIso8601String(),
    'status': status,
    'retry_count': retryCount,
  };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
    id: json['id'] as String,
    type: json['type'] as String,
    data: json['data'] as Map<String, dynamic>,
    imagePath: json['image_path'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    status: json['status'] as String? ?? 'pending',
    retryCount: json['retry_count'] as int? ?? 0,
  );
}

/// File d'attente de synchronisation locale (Hive-backed).
///
/// Stocke les items à synchroniser (images, validations, diagnostics)
/// pour upload quand la connexion internet sera disponible.
@lazySingleton
class SyncQueue {
  final Box<String> _box;

  SyncQueue({@Named('syncBox') required Box<String> box}) : _box = box;

  /// Ajoute un item à la file d'attente.
  Future<void> enqueue(SyncItem item) async {
    await _box.put(item.id, jsonEncode(item.toJson()));
    if (kDebugMode) {
      debugPrint('📥 SyncQueue: ajouté ${item.type} (${item.id})');
    }
  }

  /// Récupère tous les items en attente.
  Future<List<SyncItem>> getPending() async {
    final items = <SyncItem>[];
    final keys = _box.keys.toList(); // ← snapshot immutable
    for (final key in keys) {
      try {
        final json = _box.get(key);
        if (json != null) {
          final item = SyncItem.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          if (item.status == 'pending') {
            items.add(item);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ SyncQueue: erreur lecture $key: $e');
      }
    }
    // Tri par date de création (FIFO)
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  /// Marque un item comme terminé.
  Future<void> markCompleted(String id) async {
    final json = _box.get(id);
    if (json != null) {
      final item = SyncItem.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final updated = item.copyWith(status: 'completed');
      await _box.put(id, jsonEncode(updated.toJson()));
    }
  }

  /// Marque un item comme définitivement échoué (max retries atteint).
  Future<void> markPermanentlyFailed(String id) async {
    final json = _box.get(id);
    if (json != null) {
      final item = SyncItem.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final updated = item.copyWith(status: 'permanently_failed');
      await _box.put(id, jsonEncode(updated.toJson()));
      if (kDebugMode) {
        debugPrint('💀 SyncQueue: item $id marqué permanently_failed');
      }
    }
  }

  /// Marque un item comme échoué (incrémente le retry count).
  Future<void> markFailed(String id) async {
    final json = _box.get(id);
    if (json != null) {
      final item = SyncItem.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final updated = item.copyWith(
        status: 'pending',
        retryCount: item.retryCount + 1,
      );
      await _box.put(id, jsonEncode(updated.toJson()));
    }
  }

  /// Retourne le nombre d'items en attente.
  Future<int> get pendingCount async {
    int count = 0;
    for (final key in _box.keys) {
      try {
        final json = _box.get(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          if (data['status'] == 'pending') {
            count++;
          }
        }
      } catch (_) {}
    }
    return count;
  }

  /// Nettoie les items terminés de plus de 7 jours.
  Future<void> cleanup() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final keysToDelete = <dynamic>[];

    final keys = _box.keys.toList(); // ← snapshot immutable
    for (final key in keys) {
      try {
        final json = _box.get(key);
        if (json != null) {
          final item = SyncItem.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          if (item.status == 'completed' && item.createdAt.isBefore(cutoff)) {
            keysToDelete.add(key);
          }
        }
      } catch (_) {}
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
    }

    if (keysToDelete.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '🧹 SyncQueue cleanup: ${keysToDelete.length} items supprimés',
        );
      }
    }
  }
}
