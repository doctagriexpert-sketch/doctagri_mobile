/// Entité représentant les informations complètes d'une maladie
/// depuis la base de connaissances agronomique.
///
/// Séparée du modèle ML: le modèle retourne un label,
/// et cette entité fournit toutes les informations associées.
///
/// Les champs `*Translations` (optionnels) contiennent des variantes
/// dans les langues locales (clés : `ee` = Ewe, `kab` = Kabyè). Ils
/// permettent à l'UI / TTS de présenter le diagnostic dans la langue
/// active de l'agriculteur.
class DiseaseInfo {
  final String modelLabel;
  final String culture;
  final String displayName;
  final String description;
  final String severity;
  final List<String> symptoms;
  final List<Treatment> treatments;
  final List<TreatmentProduct> products;
  final List<String> prevention;

  /// Traductions du `displayName` par code langue (`ee`, `kab`).
  final Map<String, String> displayNameTranslations;

  /// Traductions de la `description` par code langue.
  final Map<String, String> descriptionTranslations;

  /// Traduction d'une explication courte et claire (1-2 phrases) par
  /// code langue. Spécifiquement rédigée pour la lecture vocale et
  /// l'agriculteur non-spécialiste.
  final Map<String, String> plainExplanationTranslations;

  const DiseaseInfo({
    required this.modelLabel,
    required this.culture,
    required this.displayName,
    required this.description,
    required this.severity,
    required this.symptoms,
    required this.treatments,
    required this.products,
    required this.prevention,
    this.displayNameTranslations = const {},
    this.descriptionTranslations = const {},
    this.plainExplanationTranslations = const {},
  });

  /// Retourne le `displayName` localisé selon le code langue (fallback FR).
  String localizedDisplayName(String langCode) {
    if (langCode == 'fr') return displayName;
    return displayNameTranslations[langCode] ?? displayName;
  }

  /// Retourne la `description` localisée selon le code langue (fallback FR).
  String localizedDescription(String langCode) {
    if (langCode == 'fr') return description;
    return descriptionTranslations[langCode] ?? description;
  }

  /// Explication simple destinée à la lecture vocale ; fallback sur la
  /// description longue si aucune variante simple n'existe.
  String localizedPlainExplanation(String langCode) {
    final fromMap = plainExplanationTranslations[langCode];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    if (langCode == 'fr') {
      // Plain explanation par défaut en FR : on prend la première
      // phrase de la description pour rester court à l'oral.
      final firstSentence = description.split(RegExp(r'(?<=[.!?])\s')).first;
      return firstSentence;
    }
    return localizedDescription(langCode);
  }

  /// Returns a copy of this [DiseaseInfo] with a NLLB-translated plain
  /// explanation stored for [langCode]. Used to apply runtime translations
  /// from the Edge Function without mutating the original knowledge base.
  DiseaseInfo withPlainExplanationOverride(String langCode, String text) {
    return DiseaseInfo(
      modelLabel: modelLabel,
      culture: culture,
      displayName: displayName,
      description: description,
      severity: severity,
      symptoms: symptoms,
      treatments: treatments,
      products: products,
      prevention: prevention,
      displayNameTranslations: displayNameTranslations,
      descriptionTranslations: descriptionTranslations,
      plainExplanationTranslations: {
        ...plainExplanationTranslations,
        langCode: text,
      },
    );
  }

  factory DiseaseInfo.fromJson(Map<String, dynamic> json) {
    return DiseaseInfo(
      modelLabel: json['model_label'] as String,
      culture: json['culture'] as String? ?? '',
      displayName: json['display_name'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String? ?? 'inconnu',
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      treatments: (json['treatments'] as List<dynamic>?)
              ?.map((e) => Treatment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      products: (json['products'] as List<dynamic>?)
              ?.map(
                  (e) => TreatmentProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      prevention: (json['prevention'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      displayNameTranslations: _readStringMap(json['display_name_i18n']),
      descriptionTranslations: _readStringMap(json['description_i18n']),
      plainExplanationTranslations:
          _readStringMap(json['plain_explanation_i18n']),
    );
  }

  static Map<String, String> _readStringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  /// Vérifie si la plante est saine (pas de maladie)
  bool get isHealthy =>
      modelLabel.toLowerCase().contains('healthy') ||
      severity == 'aucune';

  /// Retourne la couleur sémantique de gravité
  /// (utilisé côté présentation pour le badge)
  String get severityLevel {
    switch (severity) {
      case 'critique':
        return 'critical';
      case 'grave':
        return 'high';
      case 'modéré':
        return 'medium';
      case 'faible':
        return 'low';
      default:
        return 'none';
    }
  }
}

/// Méthode de traitement structurée
class Treatment {
  final String method;
  final String description;
  final List<String> steps;

  const Treatment({
    required this.method,
    required this.description,
    required this.steps,
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      method: json['method'] as String,
      description: json['description'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Produit de traitement avec dosage et précautions
///
/// Champs commerciaux (priceXof, sku, vendor) ajoutés en Phase 2 pour
/// supporter le flux d'achat Mobile Money. Restent nullable pour la
/// rétro-compatibilité des données sans prix.
class TreatmentProduct {
  final String name;
  final String dosage;
  final String precautions;

  /// Prix en FCFA (XOF). `null` = produit non commercialisé via l'app.
  final double? priceXof;

  /// Référence produit interne (ex: "DGA-1234").
  final String? sku;

  /// Nom du revendeur (ex: "DoctAgri Shop").
  final String? vendor;

  const TreatmentProduct({
    required this.name,
    required this.dosage,
    required this.precautions,
    this.priceXof,
    this.sku,
    this.vendor,
  });

  factory TreatmentProduct.fromJson(Map<String, dynamic> json) {
    return TreatmentProduct(
      name: json['name'] as String,
      dosage: json['dosage'] as String? ?? '',
      precautions: json['precautions'] as String? ?? '',
      priceXof: (json['priceXof'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
      vendor: json['vendor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'precautions': precautions,
        if (priceXof != null) 'priceXof': priceXof,
        if (sku != null) 'sku': sku,
        if (vendor != null) 'vendor': vendor,
      };

  TreatmentProduct copyWith({
    String? name,
    String? dosage,
    String? precautions,
    double? priceXof,
    String? sku,
    String? vendor,
  }) {
    return TreatmentProduct(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      precautions: precautions ?? this.precautions,
      priceXof: priceXof ?? this.priceXof,
      sku: sku ?? this.sku,
      vendor: vendor ?? this.vendor,
    );
  }

  /// Indique si le produit est achetable (prix renseigné).
  bool get isPurchasable => priceXof != null && priceXof! > 0;
}
