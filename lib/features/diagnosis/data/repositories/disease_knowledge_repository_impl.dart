import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/disease_info.dart';
import '../../domain/repositories/disease_knowledge_repository.dart';

/// Implémentation du repository de connaissances agronomiques.
///
/// Charge diseases_knowledge.json au démarrage et maintient
/// un index en mémoire pour un lookup O(1) par label TFLite.
@LazySingleton(as: DiseaseKnowledgeRepository)
class DiseaseKnowledgeRepositoryImpl implements DiseaseKnowledgeRepository {
  /// Index par label TFLite pour lookup rapide
  final Map<String, DiseaseInfo> _diseasesByLabel = {};

  /// Liste complète des maladies
  final List<DiseaseInfo> _allDiseases = [];

  bool _isInitialized = false;

  @override
  bool get isReady => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('📚 Chargement base de connaissances agronomiques...');
      }

      final jsonString = await rootBundle.loadString(
        'assets/data/diseases_knowledge.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      for (final item in jsonList) {
        final disease = DiseaseInfo.fromJson(item as Map<String, dynamic>);
        _allDiseases.add(disease);
        _diseasesByLabel[disease.modelLabel] = disease;
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint(
          '✅ Base de connaissances chargée: ${_allDiseases.length} maladies',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur chargement base de connaissances: $e');
      }
      _isInitialized = false;
    }
  }

  @override
  DiseaseInfo? getDiseaseByLabel(String modelLabel) {
    return _diseasesByLabel[modelLabel];
  }

  @override
  List<DiseaseInfo> getAllDiseases() {
    return List.unmodifiable(_allDiseases);
  }

  @override
  List<DiseaseInfo> getDiseasesByCulture(String culture) {
    return _allDiseases
        .where((d) => d.culture.toLowerCase() == culture.toLowerCase())
        .toList();
  }
}
