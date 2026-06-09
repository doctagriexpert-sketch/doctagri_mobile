import '../entities/validation_request.dart';

/// Repository pour gérer les demandes de validation humaine.
///
/// Stockage local (Hive) avec synchronisation future vers backend.
abstract class ValidationRepository {
  /// Soumet une demande de validation humaine.
  Future<void> submitValidation(ValidationRequest request);

  /// Récupère toutes les validations en attente.
  Future<List<ValidationRequest>> getPendingValidations();

  /// Marque une validation comme synchronisée avec le backend.
  Future<void> markAsSynced(String id);

  /// Retourne le nombre de validations en attente.
  Future<int> getPendingCount();
}
