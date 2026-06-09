import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../domain/entities/diagnosis_explanation.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../domain/entities/disease_info.dart';
import '../providers/diagnosis_provider.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 85,
          height: 85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        Gaps.v21,
        Text(
          'Analyse en cours...',
          style: AppTypography.h3.copyWith(color: AppColors.bark),
        ),
        Gaps.v14,
        Container(
          padding: Spacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.fog.withAlpha(50),
            borderRadius: AppRadius.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressStep(label: 'Prétraitement de l\'image', done: true),
              Gaps.v7,
              ProgressStep(label: 'Analyse par IA', done: true),
              Gaps.v7,
              ProgressStep(label: 'Recherche recommandations', done: false),
            ],
          ),
        ),
        Gaps.v14,
        Text(
          'Quelques secondes...',
          style: AppTypography.caption.copyWith(color: AppColors.bark),
        ),
      ],
    );
  }
}

class ProgressStep extends StatelessWidget {
  final String label;
  final bool done;

  const ProgressStep({super.key, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? AppColors.healthy : AppColors.fog,
          size: 18,
        ),
        Gaps.h11,
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: done ? AppColors.bark : AppColors.fog,
              fontWeight: done ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(20),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.danger.withAlpha(100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 34),
              Gaps.h14,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erreur d\'analyse',
                      style: AppTypography.h3.copyWith(color: AppColors.danger),
                    ),
                    Gaps.v5,
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.danger.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gaps.v14,
          Divider(color: AppColors.danger.withAlpha(60)),
          Gaps.v11,
          Text(
            'Suggestions :',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.bark,
            ),
          ),
          Gaps.v7,
          Text(
            '• Vérifiez que le modèle IA est chargé\n'
            '• Assurez-vous que l\'image est valide\n'
            '• Redémarrez l\'app si le problème persiste',
            style: TextStyle(fontSize: 12, color: AppColors.bark),
          ),
          Gaps.v14,
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessState extends StatelessWidget {
  final DiagnosisResult result;
  final DiseaseInfo? diseaseInfo;
  final DiagnosisExplanation? explanation;
  final bool validationRequested;
  final VoidCallback onReset;
  final VoidCallback onRetakePhoto;
  final VoidCallback onRequestValidation;

  const SuccessState({
    super.key,
    required this.result,
    this.diseaseInfo,
    this.explanation,
    required this.validationRequested,
    required this.onReset,
    required this.onRetakePhoto,
    required this.onRequestValidation,
  });

  @override
  Widget build(BuildContext context) {
    final confidence = result.confidence;
    final lang = context.watch<LanguageService>();
    final localizedName = diseaseInfo?.localizedDisplayName(lang.languageCode) ??
        result.diseaseName ??
        result.label;
    final localizedDescription =
        diseaseInfo?.localizedDescription(lang.languageCode) ??
            result.diseaseDescription ??
            '';

    return Column(
      children: [
        DiagnosisCard(
          label: localizedName,
          confidence: confidence,
          severity: result.severity,
        ),
        Gaps.v14,
        if (explanation != null) ...[
          PlainExplanationCard(explanation: explanation!),
          Gaps.v11,
        ],
        VoiceControls(
          result: result,
          diseaseInfo: diseaseInfo,
          explanation: explanation,
        ),
        Gaps.v21,
        if (localizedDescription.isNotEmpty) ...[
          DescriptionCard(description: localizedDescription),
          Gaps.v14,
        ],
        ConfidenceExplanation(confidence: confidence),
        Gaps.v21,
        if (diseaseInfo != null && diseaseInfo!.symptoms.isNotEmpty) ...[
          SectionHeader(title: 'Symptômes', icon: Icons.visibility),
          Gaps.v11,
          SymptomsCard(symptoms: diseaseInfo!.symptoms),
          Gaps.v21,
        ],
        if (diseaseInfo != null && diseaseInfo!.treatments.isNotEmpty) ...[
          SectionHeader(title: 'Traitements', icon: Icons.healing),
          Gaps.v11,
          ...diseaseInfo!.treatments.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: TreatmentMethodCard(treatment: t),
            ),
          ),
          Gaps.v11,
        ],
        if (diseaseInfo != null && diseaseInfo!.products.isNotEmpty) ...[
          SectionHeader(
            title: 'Produits recommandés',
            icon: Icons.local_pharmacy,
          ),
          Gaps.v11,
          ...diseaseInfo!.products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: ProductCard(product: p),
            ),
          ),
          Gaps.v11,
        ],
        if (diseaseInfo != null && diseaseInfo!.prevention.isNotEmpty) ...[
          SectionHeader(title: 'Prévention', icon: Icons.shield),
          Gaps.v11,
          PreventionCard(prevention: diseaseInfo!.prevention),
          Gaps.v21,
        ],
        if (diseaseInfo == null && result.treatmentAdvice.isNotEmpty) ...[
          SectionHeader(title: 'Recommandations', icon: Icons.spa),
          Gaps.v14,
          LegacyTreatmentCard(treatment: result.treatmentAdvice),
          Gaps.v21,
        ],
        if (!validationRequested) ...[
          ValidationButton(onPressed: onRequestValidation),
          Gaps.v11,
        ],
        if (validationRequested) ...[ValidationConfirmation(), Gaps.v11],
        if (confidence < 0.4) ...[
          OutlinedButton.icon(
            onPressed: onRetakePhoto,
            icon: const Icon(Icons.camera_alt, color: AppColors.warning),
            label: Text(
              'Reprendre une photo',
              style: TextStyle(color: AppColors.warning, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.warning, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
            ),
          ),
          Gaps.v11,
        ],
        OutlinedButton(
          onPressed: onReset,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, color: AppColors.primary),
              Gaps.h11,
              Text(
                'Nouveau diagnostic',
                style: TextStyle(color: AppColors.primary, fontSize: 16),
              ),
            ],
          ),
        ),
        Gaps.v21,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        Gaps.h7,
        Text(title, style: AppTypography.h2Dark),
      ],
    );
  }
}

class DiagnosisCard extends StatelessWidget {
  final String label;
  final double confidence;
  final String? severity;

  const DiagnosisCard({
    super.key,
    required this.label,
    required this.confidence,
    this.severity,
  });

  Color get _statusColor {
    if (confidence > 0.7) return AppColors.healthy;
    if (confidence > 0.4) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusColor.withAlpha(25),
        borderRadius: AppRadius.medium,
        border: Border.all(color: _statusColor.withAlpha(100), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                label.contains('Sain') || label.contains('sain')
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: _statusColor,
                size: 36,
              ),
              Gaps.h14,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIAGNOSTIC',
                      style: TextStyle(
                        color: AppColors.bark.withAlpha(150),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gaps.v5,
                    Text(
                      'Confiance: ${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: AppColors.bark.withAlpha(150),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (severity != null &&
              severity != 'aucune' &&
              severity!.isNotEmpty) ...[
            Gaps.v11,
            Row(children: [SeverityBadge(severity: severity!)]),
          ],
        ],
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final String severity;

  const SeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity) {
      case 'critique':
        return const Color(0xFFDC2626);
      case 'grave':
        return const Color(0xFFEA580C);
      case 'modéré':
        return AppColors.warning;
      case 'faible':
        return AppColors.healthy;
      default:
        return AppColors.fog;
    }
  }

  String get _label {
    switch (severity) {
      case 'critique':
        return '⚠️ CRITIQUE';
      case 'grave':
        return '🔴 GRAVE';
      case 'modéré':
        return '🟡 MODÉRÉ';
      case 'faible':
        return '🟢 FAIBLE';
      default:
        return severity.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withAlpha(100)),
      ),
      child: Text(
        'Gravité : $_label',
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DescriptionCard extends StatelessWidget {
  final String description;

  const DescriptionCard({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fog.withAlpha(30),
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              Gaps.h7,
              Text(
                'Explication',
                style: AppTypography.h3.copyWith(color: AppColors.bark),
              ),
            ],
          ),
          Gaps.v11,
          Text(
            description,
            style: TextStyle(fontSize: 14, color: AppColors.bark, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class ConfidenceExplanation extends StatelessWidget {
  final double confidence;

  const ConfidenceExplanation({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    final Color color;
    final IconData icon;

    if (confidence > 0.7) {
      title = 'Résultat fiable';
      message = 'L\'IA est très confiante dans ce diagnostic.';
      color = AppColors.healthy;
      icon = Icons.verified;
    } else if (confidence > 0.4) {
      title = 'Résultat modéré';
      message =
          'Le diagnostic est probable mais pourrait nécessiter une confirmation.';
      color = AppColors.warning;
      icon = Icons.warning_amber;
    } else {
      title = 'Résultat incertain';
      message =
          'Prenez une nouvelle photo avec:\n• Meilleur éclairage\n• Feuille bien centrée\n• Image nette';
      color = AppColors.danger;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: AppRadius.small,
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          Gaps.h11,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Gaps.v5,
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.bark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SymptomsCard extends StatelessWidget {
  final List<String> symptoms;

  const SymptomsCard({super.key, required this.symptoms});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(12),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.warning.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: symptoms
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.bark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class TreatmentMethodCard extends StatelessWidget {
  final Treatment treatment;

  const TreatmentMethodCard({super.key, required this.treatment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sage.withAlpha(20),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.sage.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            treatment.method,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (treatment.description.isNotEmpty) ...[
            Gaps.v5,
            Text(
              treatment.description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.bark.withAlpha(180),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (treatment.steps.isNotEmpty) ...[
            Gaps.v11,
            ...treatment.steps.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.bark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final TreatmentProduct product;

  const ProductCard({super.key, required this.product});

  static final _fmt = NumberFormat.decimalPattern('fr_FR');

  String? _formattedPrice() {
    final value = product.priceXof;
    if (value == null || value <= 0) return null;
    return '${_fmt.format(value)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final price = _formattedPrice();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fog.withAlpha(30),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.fog.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_pharmacy, color: AppColors.accent, size: 20),
              Gaps.h7,
              Expanded(
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bark,
                  ),
                ),
              ),
              if (price != null) ...[
                Gaps.h7,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withAlpha(80),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    price,
                    style: AppTypography.priceTag.copyWith(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Gaps.v11,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Dosage',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Gaps.h7,
              Expanded(
                child: Text(
                  product.dosage,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.bark,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (product.precautions.isNotEmpty) ...[
            Gaps.v7,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Attention',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                Gaps.h7,
                Expanded(
                  child: Text(
                    product.precautions,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.bark.withAlpha(180),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (product.isPurchasable) ...[
            Gaps.v11,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/checkout', extra: product),
                icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                label: const Text(
                  'Acheter ce produit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PreventionCard extends StatelessWidget {
  final List<String> prevention;

  const PreventionCard({super.key, required this.prevention});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.healthy.withAlpha(12),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.healthy.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: prevention
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.healthy,
                      size: 16,
                    ),
                    Gaps.h7,
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.bark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class ValidationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ValidationButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.warning, size: 28),
              Gaps.h11,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consulter un expert',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    Gaps.v3,
                    Text(
                      'Obtenez l\'avis d\'un agronome. '
                      'La photo et le diagnostic seront partagés directement.',
                      style: TextStyle(fontSize: 12, color: AppColors.bark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gaps.v14,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.person_search, size: 18),
              label: const Text('Contacter un expert sur WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ValidationConfirmation extends StatelessWidget {
  const ValidationConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.healthy.withAlpha(15),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.healthy.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.healthy, size: 24),
          Gaps.h11,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partage lancé !',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.healthy,
                  ),
                ),
                Gaps.v3,
                Text(
                  'Sélectionnez WhatsApp dans le menu partage, '
                  'puis envoyez à l\'expert : +22891774563',
                  style: TextStyle(fontSize: 12, color: AppColors.bark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'explication en langage simple, mise en avant après le
/// diagnostic. Le texte est déjà localisé dans la langue active.
/// Le bandeau de gauche donne un repère visuel (icône haut-parleur)
/// pour rappeler que cette explication est aussi lue à voix haute.
class PlainExplanationCard extends StatelessWidget {
  final DiagnosisExplanation explanation;

  const PlainExplanationCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final voiceService = context.watch<VoiceService>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              voiceService.isSpeaking
                  ? Icons.graphic_eq_rounded
                  : Icons.record_voice_over_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          Gaps.h11,
          Expanded(
            child: Text(
              explanation.plainText,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.bark,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contrôles vocaux : bouton "Écouter à nouveau" en version courte,
/// "Écouter en détail" en version longue, et un interrupteur pour
/// désactiver la lecture automatique. La langue suit toujours la
/// préférence active de l'utilisateur.
class VoiceControls extends StatelessWidget {
  final DiagnosisResult result;
  final DiseaseInfo? diseaseInfo;
  final DiagnosisExplanation? explanation;

  const VoiceControls({
    super.key,
    required this.result,
    this.diseaseInfo,
    this.explanation,
  });

  String _replayLabel(LanguageService lang) => switch (lang.languageCode) {
        'ee' => 'Gase',
        'kab' => 'Gase',
        _ => 'Écouter à nouveau',
      };

  String _detailLabel(LanguageService lang) => switch (lang.languageCode) {
        'ee' => 'Se nyateƒe blibo',
        'kab' => 'Se nyateƒe blibo',
        _ => 'Écouter en détail',
      };

  String _stopLabel(LanguageService lang) => switch (lang.languageCode) {
        'ee' => 'Tɔ',
        'kab' => 'Tɔ',
        _ => 'Arrêter',
      };

  String _autoLabel(LanguageService lang) => switch (lang.languageCode) {
        'ee' => 'Lecture automatique',
        'kab' => 'Lecture automatique',
        _ => 'Lecture automatique',
      };

  @override
  Widget build(BuildContext context) {
    final voiceService = context.watch<VoiceService>();
    final langService = context.watch<LanguageService>();
    final provider = context.watch<DiagnosisProvider>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: voiceService.isSpeaking
                    ? () => voiceService.stopSpeaking()
                    : explanation == null
                        ? null
                        : () => provider.speakPlain(),
                icon: Icon(
                  voiceService.isSpeaking
                      ? Icons.stop
                      : Icons.volume_up_rounded,
                  color: voiceService.isSpeaking
                      ? AppColors.danger
                      : AppColors.primary,
                  size: 20,
                ),
                label: Text(
                  voiceService.isSpeaking
                      ? _stopLabel(langService)
                      : _replayLabel(langService),
                  style: TextStyle(
                    color: voiceService.isSpeaking
                        ? AppColors.danger
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: voiceService.isSpeaking
                        ? AppColors.danger
                        : AppColors.primary,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
                ),
              ),
            ),
            Gaps.h7,
            Expanded(
              child: OutlinedButton.icon(
                onPressed: voiceService.isSpeaking || explanation == null
                    ? null
                    : () => provider.speakDetailed(),
                icon: const Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                label: Text(
                  _detailLabel(langService),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.primary.withAlpha(120),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
                ),
              ),
            ),
          ],
        ),
        Gaps.v7,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _autoLabel(langService),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.bark.withAlpha(180),
              ),
            ),
            Gaps.h7,
            Switch(
              value: provider.autoSpeakEnabled,
              onChanged: (v) => provider.setAutoSpeakEnabled(v),
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class LegacyTreatmentCard extends StatelessWidget {
  final String treatment;

  const LegacyTreatmentCard({super.key, required this.treatment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fog.withAlpha(40),
        borderRadius: AppRadius.cardMain,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.sage.withAlpha(60),
            child: const Icon(Icons.spa, color: AppColors.primary, size: 22),
          ),
          Gaps.h14,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Traitement suggéré',
                  style: AppTypography.h3.copyWith(color: AppColors.bark),
                ),
                Gaps.v5,
                Text(treatment, style: AppTypography.bodyDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
