import '../entities/diagnosis_result.dart';
import '../entities/disease_info.dart';

/// Texte structuré que l'on peut à la fois AFFICHER (UI) et LIRE (TTS).
///
/// Le champ [plainText] est une explication claire en langage simple pour
/// la lecture vocale et l'affichage principal. Les autres champs sont des
/// briques utilisées par la fiche détaillée du résultat.
class DiagnosisExplanation {
  /// Une / deux phrases courtes : la maladie + ce qu'il faut faire en
  /// premier. Spécifiquement rédigée pour la lecture à voix haute.
  final String plainText;

  /// Texte long fusionnant nom, description, symptômes, traitement,
  /// prévention. Utilisé par le bouton "Écouter" si l'utilisateur veut
  /// la version détaillée.
  final String detailedText;

  /// Code de la langue dans laquelle ce texte a été produit
  /// (`fr`, `ee`, `kab`).
  final String langCode;

  const DiagnosisExplanation({
    required this.plainText,
    required this.detailedText,
    required this.langCode,
  });
}

/// Construit une [DiagnosisExplanation] dans la langue voulue à partir
/// d'un [DiagnosisResult] et, si dispo, d'un [DiseaseInfo] détaillé.
///
/// Le builder est volontairement sans état et sans dépendances Flutter :
/// il peut être appelé depuis le provider ou un test unitaire.
class DiagnosisExplanationBuilder {
  const DiagnosisExplanationBuilder();

  DiagnosisExplanation build({
    required DiagnosisResult result,
    DiseaseInfo? info,
    required String langCode,
  }) {
    final dict = _Dictionary.forLanguage(langCode);

    final name = info?.localizedDisplayName(langCode) ??
        result.diseaseName ??
        result.label;

    final plain = _buildPlain(
      result: result,
      info: info,
      langCode: langCode,
      dict: dict,
      name: name,
    );

    final detailed = _buildDetailed(
      result: result,
      info: info,
      langCode: langCode,
      dict: dict,
      name: name,
    );

    return DiagnosisExplanation(
      plainText: plain,
      detailedText: detailed,
      langCode: langCode,
    );
  }

  String _buildPlain({
    required DiagnosisResult result,
    required DiseaseInfo? info,
    required String langCode,
    required _Dictionary dict,
    required String name,
  }) {
    final buffer = StringBuffer();
    buffer.write(dict.diagnosisIs);
    buffer.write(' ');
    buffer.write(name);
    buffer.write('. ');

    if (info != null) {
      // 1) Explication courte localisée
      final plain = info.localizedPlainExplanation(langCode);
      if (plain.isNotEmpty) {
        buffer.write(plain);
        if (!plain.endsWith('.') && !plain.endsWith('!')) {
          buffer.write('.');
        }
        buffer.write(' ');
      }

      // 2) Niveau de gravité (en mots simples)
      final severity = info.severity;
      if (severity.isNotEmpty && severity != 'aucune' && severity != 'inconnu') {
        buffer.write(dict.severityLabel);
        buffer.write(' : ');
        buffer.write(_severityWord(severity, dict));
        buffer.write('. ');
      }

      // 3) Première action à faire (1ère étape du 1er traitement)
      if (info.treatments.isNotEmpty &&
          info.treatments.first.steps.isNotEmpty) {
        buffer.write(dict.firstAction);
        buffer.write(' : ');
        buffer.write(info.treatments.first.steps.first);
        if (!info.treatments.first.steps.first.endsWith('.')) {
          buffer.write('.');
        }
      }
    } else {
      // Sans info détaillée, on indique au moins la confiance.
      final pct = (result.confidence * 100).round();
      buffer.write(dict.confidenceLabel);
      buffer.write(' : ');
      buffer.write(pct);
      buffer.write(' ');
      buffer.write(dict.percent);
      buffer.write('.');
    }

    return _normalize(buffer.toString());
  }

  String _buildDetailed({
    required DiagnosisResult result,
    required DiseaseInfo? info,
    required String langCode,
    required _Dictionary dict,
    required String name,
  }) {
    final buffer = StringBuffer();
    buffer.write('${dict.intro} $name. ');

    final pct = (result.confidence * 100).round();
    buffer.write('${dict.confidenceLabel} : $pct ${dict.percent}. ');

    if (info != null) {
      final desc = info.localizedDescription(langCode);
      if (desc.isNotEmpty) {
        buffer.write('$desc ');
      }

      if (info.symptoms.isNotEmpty) {
        buffer.write('${dict.symptomsLabel} : ');
        buffer.write(info.symptoms.join(', '));
        buffer.write('. ');
      }

      if (info.treatments.isNotEmpty) {
        buffer.write('${dict.treatmentLabel} : ');
        for (final t in info.treatments) {
          buffer.write('${t.method}. ');
          if (t.steps.isNotEmpty) {
            for (var i = 0; i < t.steps.length; i++) {
              buffer.write('${i + 1}. ${t.steps[i]}. ');
            }
          }
        }
      }

      if (info.prevention.isNotEmpty) {
        buffer.write('${dict.preventionLabel} : ');
        buffer.write(info.prevention.join('. '));
        buffer.write('.');
      }
    } else if (result.treatmentAdvice.isNotEmpty) {
      buffer.write(result.treatmentAdvice);
    }

    return _normalize(buffer.toString());
  }

  String _severityWord(String severity, _Dictionary dict) {
    switch (severity) {
      case 'critique':
        return dict.severityCritical;
      case 'grave':
        return dict.severityHigh;
      case 'modéré':
        return dict.severityMedium;
      case 'faible':
        return dict.severityLow;
      default:
        return severity;
    }
  }

  /// Compresse les espaces et retire les caractères Ewe / Kabyè qui
  /// posent problème à la plupart des moteurs TTS (ɛ, ɔ, ɖ, ƒ, ŋ).
  String _normalize(String s) {
    final compact = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact;
  }
}

/// Vocabulaire localisé minimal pour construire une explication.
class _Dictionary {
  final String diagnosisIs;
  final String intro;
  final String confidenceLabel;
  final String percent;
  final String severityLabel;
  final String severityCritical;
  final String severityHigh;
  final String severityMedium;
  final String severityLow;
  final String firstAction;
  final String symptomsLabel;
  final String treatmentLabel;
  final String preventionLabel;

  const _Dictionary({
    required this.diagnosisIs,
    required this.intro,
    required this.confidenceLabel,
    required this.percent,
    required this.severityLabel,
    required this.severityCritical,
    required this.severityHigh,
    required this.severityMedium,
    required this.severityLow,
    required this.firstAction,
    required this.symptomsLabel,
    required this.treatmentLabel,
    required this.preventionLabel,
  });

  static _Dictionary forLanguage(String code) {
    switch (code) {
      case 'ee':
        return const _Dictionary(
          diagnosisIs: 'Dɔwɔna ƒe ema enye',
          intro: 'Dɔwɔna ƒe ema:',
          confidenceLabel: 'Ðoɖo',
          percent: 'alafa me',
          severityLabel: 'Sesẽme',
          severityCritical: 'sesẽ ŋutɔ',
          severityHigh: 'sesẽ',
          severityMedium: 'titina',
          severityLow: 'sue',
          firstAction: 'Nu si nèwɔ gbã',
          symptomsLabel: 'Dɔmegblẽwo',
          treatmentLabel: 'Dɔwɔna',
          preventionLabel: 'Dzidzedze',
        );
      case 'kab':
        return const _Dictionary(
          diagnosisIs: 'Dɔwɔna ɛ ema enye',
          intro: 'Dɔwɔna ɛ ema:',
          confidenceLabel: 'Ðoɖo',
          percent: 'alafa me',
          severityLabel: 'Sesẽme',
          severityCritical: 'sesẽ ŋutɔ',
          severityHigh: 'sesẽ',
          severityMedium: 'titina',
          severityLow: 'sue',
          firstAction: 'Nu si nèwɔ gbã',
          symptomsLabel: 'Dɔmegblẽwo',
          treatmentLabel: 'Dɔwɔna',
          preventionLabel: 'Dzidzedze',
        );
      default:
        return const _Dictionary(
          diagnosisIs: 'Le diagnostic est',
          intro: 'Résultat du diagnostic :',
          confidenceLabel: 'Confiance',
          percent: 'pourcent',
          severityLabel: 'Gravité',
          severityCritical: 'critique',
          severityHigh: 'grave',
          severityMedium: 'modérée',
          severityLow: 'faible',
          firstAction: 'Première chose à faire',
          symptomsLabel: 'Symptômes',
          treatmentLabel: 'Traitement',
          preventionLabel: 'Prévention',
        );
    }
  }
}
