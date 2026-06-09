import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/entities/diagnosis_result.dart';
import '../../domain/entities/disease_info.dart';
import '../providers/diagnosis_provider.dart';
import '../widgets/result_widgets.dart';

class ResultPage extends StatefulWidget {
  final String imagePath;

  const ResultPage({super.key, required this.imagePath});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiagnosisProvider>().analyzeImage(widget.imagePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.bark),
          onPressed: () => context.pop(),
        ),
        title: Text('Résultat', style: AppTypography.h2Dark),
        centerTitle: true,
      ),
      body: Consumer<DiagnosisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: Spacing.pagePadding,
            child: Column(
              children: [
                _buildImagePreview(),
                Gaps.v34,
                _buildContent(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Expert WhatsApp share ─────────────────────────────────────────────────

  static const _expertPhone = '+22891774563';

  Future<void> _shareWithExpert(
    DiagnosisResult result,
    DiseaseInfo? info,
  ) async {
    try {
      await Share.shareXFiles(
        [XFile(result.imagePath)],
        subject: 'Diagnostic DoctAgri — ${info?.displayName ?? result.diseaseName ?? result.label}',
        text: _buildExpertMessage(result, info),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ResultPage] Share error: $e');
    }
  }

  static String _buildExpertMessage(DiagnosisResult result, DiseaseInfo? info) {
    final name = info?.displayName ?? result.diseaseName ?? result.label;
    final pct  = (result.confidence * 100).round();
    final sev  = info?.severity ?? result.severity ?? '';
    final crop = info?.culture ?? '';
    final date = DateFormat('dd/MM/yyyy à HH:mm').format(result.timestamp);

    final buf = StringBuffer();

    buf.writeln('📱 *Expert DoctAgri : $_expertPhone*');
    buf.writeln();
    buf.writeln('🌿 *Résultat du diagnostic*');
    buf.writeln('────────────────────────');
    buf.writeln('🔬 Maladie détectée : *$name*');
    buf.writeln('📊 Fiabilité de l\'IA : *$pct %*');
    if (sev.isNotEmpty && sev != 'inconnu') {
      buf.writeln('⚠️ Gravité : *$sev*');
    }
    if (crop.isNotEmpty) {
      buf.writeln('🌱 Culture : $crop');
    }

    if (info != null) {
      if (info.description.isNotEmpty) {
        buf.writeln();
        buf.writeln('📋 *Description :*');
        final d = info.description;
        buf.writeln(d.length > 300 ? '${d.substring(0, 300)}…' : d);
      }
      if (info.treatments.isNotEmpty) {
        buf.writeln();
        buf.writeln('💊 *Traitement conseillé :*');
        final t = info.treatments.first;
        buf.writeln('• ${t.method}');
        if (t.steps.isNotEmpty) buf.writeln('→ ${t.steps.first}');
      }
    } else if (result.treatmentAdvice.isNotEmpty) {
      buf.writeln();
      buf.writeln('💊 *Conseil :* ${result.treatmentAdvice}');
    }

    buf.writeln();
    buf.writeln('────────────────────────');
    buf.writeln('📅 $date');
    buf.writeln('📱 Envoyé depuis DoctAgri');
    return buf.toString().trim();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: AppRadius.cardMain,
      child: Image.file(
        File(widget.imagePath),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildContent(DiagnosisProvider provider) {
    switch (provider.status) {
      case DiagnosisStatus.loading:
        return const LoadingState();
      case DiagnosisStatus.error:
        return ErrorState(
          message: provider.errorMessage ?? 'Erreur inconnue',
          onRetry: () {
            provider.reset();
            context.pop();
          },
        );
      case DiagnosisStatus.success:
        if (provider.result == null) {
          return ErrorState(
            message: 'Aucun résultat',
            onRetry: () {
              provider.reset();
              context.pop();
            },
          );
        }
        return SuccessState(
          result: provider.result!,
          diseaseInfo: provider.diseaseInfo,
          explanation: provider.explanation,
          validationRequested: provider.validationRequested,
          onReset: () {
            provider.reset();
            context.go('/');
          },
          onRetakePhoto: () {
            provider.reset();
            context.pop();
          },
          onRequestValidation: () {
            provider.requestHumanValidation();
            // ignore: discarded_futures
            _shareWithExpert(provider.result!, provider.diseaseInfo);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
