import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../data/crop_tips_repository.dart';
import '../../domain/entities/crop_tip.dart';

/// Écran de détail d'une culture : liste des conseils avec audio + lien vidéo.
class CropDetailPage extends StatefulWidget {
  final String cropId;
  const CropDetailPage({super.key, required this.cropId});

  @override
  State<CropDetailPage> createState() => _CropDetailPageState();
}

class _CropDetailPageState extends State<CropDetailPage> {
  final CropTipsRepository _repo = CropTipsRepository();
  late Future<Crop?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.findById(widget.cropId);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.bark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<Crop?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final crop = snap.data;
          if (crop == null) {
            return const Center(child: Text('Culture introuvable'));
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: Spacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(crop.emoji, style: const TextStyle(fontSize: 44)),
                      Gaps.h14,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop.nameFor(lang.languageCode),
                              style: AppTypography.display,
                            ),
                            Gaps.v3,
                            Text(
                              '${crop.tips.length} conseil${crop.tips.length > 1 ? "s" : ""} · ${lang.languageName}',
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gaps.v21,
                  ...crop.tips.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TipCard(
                            index: e.key + 1,
                            tip: e.value,
                            langCode: lang.languageCode,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final int index;
  final CropTip tip;
  final String langCode;

  const _TipCard({
    required this.index,
    required this.tip,
    required this.langCode,
  });

  Future<void> _openVideo(BuildContext context) async {
    final url = Uri.parse(tip.videoUrl);
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la vidéo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceService>();

    // Détecte si c'est ce tip qui joue (on compare via le texte — plus simple).
    final text = tip.audioTextFor(langCode);
    final isThisSpeaking = voice.isSpeaking;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardMain,
        border: Border.all(color: AppColors.primary.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Gaps.h11,
              Expanded(
                child: Text(
                  tip.titleFor(langCode),
                  style: AppTypography.h3.copyWith(color: AppColors.bark),
                ),
              ),
            ],
          ),
          Gaps.v11,
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.bark,
              height: 1.5,
            ),
          ),
          Gaps.v14,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isThisSpeaking) {
                      voice.stopSpeaking();
                    } else {
                      voice.setLanguage(langCode);
                      voice.speak(text);
                    }
                  },
                  icon: Icon(
                    isThisSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 18,
                    color: isThisSpeaking
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                  label: Text(
                    isThisSpeaking ? 'Arrêter' : 'Écouter',
                    style: TextStyle(
                      color: isThisSpeaking
                          ? AppColors.danger
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isThisSpeaking
                          ? AppColors.danger
                          : AppColors.primary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                  ),
                ),
              ),
              if (tip.hasVideo) ...[
                Gaps.h7,
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openVideo(context),
                    icon: const Icon(Icons.play_circle_fill, size: 18),
                    label: const Text('Vidéo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
