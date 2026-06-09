import '../entities/disease_info.dart';

/// Repository pour accéder à la base de connaissances agronomique.
///
/// Séparation stricte: le modèle ML retourne un label,
/// ce repository fournit les informations associées.
abstract class DiseaseKnowledgeRepository {
  /// Charge la base de connaissances depuis les assets.
  /// Doit être appelé une fois au démarrage de l'application.
  Future<void> initialize();

  /// Récupère les informations d'une maladie par son label TFLite.
  /// Retourne null si le label n'est pas reconnu.
  DiseaseInfo? getDiseaseByLabel(String modelLabel);

  /// Retourne toutes les maladies de la base.
  List<DiseaseInfo> getAllDiseases();

  /// Retourne les maladies pour une culture donnée.
  List<DiseaseInfo> getDiseasesByCulture(String culture);

  /// Vérifie si la base est chargée et prête.
  bool get isReady;
}
