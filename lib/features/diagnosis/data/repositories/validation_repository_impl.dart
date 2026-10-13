import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/validation_request.dart';
import '../../domain/repositories/validation_repository.dart';

/// Implémentation Hive du repository de validation humaine.
///
/// Stocke les demandes localement en JSON sérialisé dans une Hive Box.
/// Prêt pour la synchronisation future avec le backend.
@LazySingleton(as: ValidationRepository)
class ValidationRepositoryImpl implements ValidationRepository {
  final Box<String> _box;

  ValidationRepositoryImpl({@Named('validationBox') required Box<String> box})
    : _box = box;

  @override
  Future<void> submitValidation(ValidationRequest request) async {
    final json = jsonEncode(request.toJson());
    await _box.put(request.id, json);
    if (kDebugMode) debugPrint('📋 Validation request saved: ${request.id}');
  }

  @override
  Future<List<ValidationRequest>> getPendingValidations() async {
    final pending = <ValidationRequest>[];
    for (final key in _box.keys) {
      try {
        final json = _box.get(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final request = ValidationRequest.fromJson(data);
          if (request.status == 'pending') {
            pending.add(request);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error reading validation $key: $e');
      }
    }
    return pending;
  }

  @override
  Future<void> markAsSynced(String id) async {
    final json = _box.get(id);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final request = ValidationRequest.fromJson(data);
      final updated = request.copyWith(status: 'synced');
      await _box.put(id, jsonEncode(updated.toJson()));
    }
  }

  @override
  Future<int> getPendingCount() async {
    int count = 0;
    for (final key in _box.keys) {
      try {
        final json = _box.get(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          if (data['status'] == 'pending') count++;
        }
      } catch (_) {}
    }
    return count;
  }
}
