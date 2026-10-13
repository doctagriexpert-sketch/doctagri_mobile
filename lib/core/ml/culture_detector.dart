/// Détection de culture (= « cette image est probablement quelle plante ? »)
/// pour décider quels modèles de diagnostic sont pertinents.
///
/// Le problème métier que ce module attaque (cf. audit qualité QW1/C3) :
///
///   Le modèle cassava classifie de force dans ses 6 classes. Si on lui
///   donne une photo de tomate malade, il sort `Cassava___healthy` à 85 %.
///   Plantvillage sort `Tomato___Early_blight` à 60 %. La fusion actuelle
///   prend le plus confiant → diagnostic « sain » sur une plante malade.
///
/// Idéalement on entraînerait un classifieur dédié (manioc / autre /
/// non-feuille). En attendant, [HeuristicCultureDetector] utilise la
/// prédiction plantvillage comme proxy de détection de culture :
/// plantvillage couvre 14 cultures non-cassava, donc une prédiction
/// confiante non-Background nous dit que l'image est probablement
/// dans son domaine — pas du manioc.
///
/// L'interface [CultureDetector] est prête à recevoir un vrai modèle
/// TFLite dédié le jour où il sera disponible : il suffira d'écrire
/// une nouvelle implémentation et de l'injecter à la place.
library;

/// Évidence brute extraite d'un modèle pour un diagnostic donné.
///
/// Le [CultureDetector] consomme ces évidences (typiquement le top-1
/// de chaque modèle) pour estimer le domaine probable de l'image.
class ModelEvidence {
  final String modelId;
  final String topLabel;
  final double topConfidence;

  /// Probabilité de la classe "background sans feuilles" si présente
  /// dans le modèle. Null si le modèle ne la prédit pas.
  final double? backgroundProb;

  const ModelEvidence({
    required this.modelId,
    required this.topLabel,
    required this.topConfidence,
    this.backgroundProb,
  });
}

/// Estimation du domaine probable de l'image, telle que produite par
/// un [CultureDetector].
///
/// Sémantique :
///   - [plausibleCultures] vide ET [confidence] == 0 → on ne sait rien.
///     `supportsCulture` retourne `true` pour toute culture (on accorde
///     le bénéfice du doute).
///   - [plausibleCultures] non vide → on a une évidence positive
///     en faveur de ces cultures et CONTRE toutes les autres.
class DomainEvidence {
  /// Cultures pour lesquelles l'image semble plausible (clé : préfixe
  /// anglais du label modèle, ex. 'Tomato', 'Cassava'). Vide = aucune
  /// évidence.
  final Set<String> plausibleCultures;

  /// Score de confiance dans cette estimation [0, 1].
  final double confidence;

  const DomainEvidence({
    required this.plausibleCultures,
    required this.confidence,
  });

  /// Pas d'information sur le domaine (cas par défaut).
  factory DomainEvidence.unknown() =>
      const DomainEvidence(plausibleCultures: {}, confidence: 0.0);

  /// True si rien ne s'oppose à ce que l'image soit de cette culture.
  /// Si on n'a aucune évidence, on dit toujours `true` (bénéfice du doute).
  bool supportsCulture(String culture) =>
      plausibleCultures.isEmpty || plausibleCultures.contains(culture);

  /// True si on a une évidence positive que l'image N'EST PAS de cette
  /// culture. Plus strict que `!supportsCulture` : exige une confiance
  /// suffisante.
  bool excludesCulture(String culture) =>
      confidence >= 0.5 &&
      plausibleCultures.isNotEmpty &&
      !plausibleCultures.contains(culture);
}

/// Détecteur de culture à partir d'évidences (top-1 des modèles).
abstract class CultureDetector {
  DomainEvidence detect(List<ModelEvidence> evidences);
}

/// Implémentation heuristique : se base sur la prédiction du modèle
/// plantvillage (qui couvre 14 cultures non-cassava) comme proxy de
/// détection de culture.
///
/// Règles :
///   1. Si plantvillage absent des évidences → DomainEvidence.unknown.
///   2. Si plantvillage a une probabilité Background > 0.25 → unknown
///      (l'image est probablement floue / pas une feuille).
///   3. Si la confiance plantvillage top-1 < `_confidenceThreshold` →
///      unknown (le modèle ne sait pas, on ne tire pas de conclusion).
///   4. Sinon : on extrait la culture depuis le label plantvillage et
///      on la déclare comme unique culture plausible.
///
/// Limites connues :
///   - Si plantvillage misclassifie un manioc en `Apple___healthy`
///     avec une confiance > 0.5, on conclut à tort qu'on n'est pas
///     en domaine manioc. Réaliste sur des feuilles très ressemblantes,
///     rare en pratique.
///   - À remplacer par un vrai TFLite dédié dès qu'on aura un set
///     manioc / autre / non-feuille étiqueté.
class HeuristicCultureDetector implements CultureDetector {
  static const double _confidenceThreshold = 0.5;
  static const double _backgroundRejectThreshold = 0.25;
  static const String _plantvillageId = 'plantvillage';

  const HeuristicCultureDetector();

  @override
  DomainEvidence detect(List<ModelEvidence> evidences) {
    final pv = _firstOrNull(evidences, (e) => e.modelId == _plantvillageId);
    if (pv == null) return DomainEvidence.unknown();

    final bg = pv.backgroundProb;
    if (bg != null && bg > _backgroundRejectThreshold) {
      return DomainEvidence.unknown();
    }

    if (pv.topConfidence < _confidenceThreshold) {
      return DomainEvidence.unknown();
    }

    final culture = extractCultureFromLabel(pv.topLabel);
    if (culture == null) return DomainEvidence.unknown();

    return DomainEvidence(
      plausibleCultures: {culture},
      confidence: pv.topConfidence,
    );
  }
}

/// Extrait le préfixe de culture d'un label modèle.
///
/// Convention des labels :
///   - Format `<Culture>___<état>` (PlantVillage + cassava namespacés)
///     → on prend la partie avant `___`.
///     Ex: `Tomato___Early_blight` → `'Tomato'`.
///          `Cassava___healthy` → `'Cassava'`.
///   - Format historique cassava `Cassava <maladie> (<sigle>)`
///     → on retourne `'Cassava'`.
///   - `Background_without_leaves` → null (pas une culture).
///   - Toute autre forme inconnue → null.
///
/// Retourne null si le label ne permet pas d'identifier une culture.
String? extractCultureFromLabel(String label) {
  if (label.contains('___')) {
    final prefix = label.split('___').first.trim();
    return prefix.isEmpty ? null : prefix;
  }
  if (label.toLowerCase().startsWith('cassava ')) {
    return 'Cassava';
  }
  return null;
}

/// Cultures prises en charge par l'app (périmètre maraîcher, focus tomate).
///
/// Les valeurs sont les **préfixes anglais** tels qu'ils apparaissent dans
/// les labels du modèle (cf. [extractCultureFromLabel]), pour permettre une
/// comparaison directe :
///   - `Tomato`       → tomate (priorité, 9 maladies couvertes)
///   - `Potato`       → pomme de terre (2 maladies)
///   - `Pepper,_bell` → piment / poivron (1 maladie)
///   - `Squash`       → courge (1 maladie)
///   - `Corn`         → maïs (3 maladies)
///
/// Toute prédiction dont la culture n'est PAS dans cet ensemble déclenche
/// une abstention côté repository (« culture non prise en charge ») plutôt
/// qu'un faux diagnostic sur une culture hors périmètre (pomme, vigne,
/// orange…). PlantVillage étant un modèle figé à 39 classes, on ne peut
/// pas lui « retirer » ces cultures : on filtre en aval.
///
/// **Pour changer le périmètre** (ex. ajouter la fraise) : éditer cet
/// ensemble. C'est l'unique source de vérité du périmètre métier.
const Set<String> kSupportedCultures = {
  'Tomato',
  'Potato',
  'Pepper,_bell',
  'Squash',
  'Corn',
};

/// True si le label appartient à une culture du périmètre [kSupportedCultures].
///
/// Retourne `false` quand la culture ne peut pas être identifiée
/// (`extractCultureFromLabel` → null), ce qui est le défaut sûr : on
/// préfère abstenir que diagnostiquer une culture inconnue. Le label
/// `Background_without_leaves` retourne donc `false` (mais il est déjà
/// intercepté en amont par la règle de rejet d'image).
bool isCultureSupported(String rawLabel) {
  final culture = extractCultureFromLabel(rawLabel);
  if (culture == null) return false;
  return kSupportedCultures.contains(culture);
}

T? _firstOrNull<T>(List<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
