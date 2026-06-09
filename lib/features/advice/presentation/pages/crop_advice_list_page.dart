import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/services/language_service.dart';
import '../../data/crop_tips_repository.dart';
import '../../domain/entities/crop_tip.dart';

/// Écran listant les cultures disponibles pour les conseils audio/vidéo.
class CropAdviceListPage extends StatefulWidget {
  const CropAdviceListPage({super.key});

  @override
  State<CropAdviceListPage> createState() => _CropAdviceListPageState();
}

class _CropAdviceListPageState extends State<CropAdviceListPage> {
  final CropTipsRepository _repo = CropTipsRepository();
  late Future<List<Crop>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.loadAll();
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
        title: const Text('Conseils par culture'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<Crop>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Text(
                'Impossible de charger les conseils',
                style: TextStyle(color: AppColors.danger),
              ),
            );
          }
          final crops = snap.data!;
          return SafeArea(
            child: SingleChildScrollView(
              padding: Spacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Écoutez des conseils en ${lang.languageName}',
                    style: AppTypography.bodySecondary,
                  ),
                  Gaps.v14,
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: crops.length,
                    itemBuilder: (context, i) => _CropTile(
                      crop: crops[i],
                      langCode: lang.languageCode,
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

class _CropTile extends StatelessWidget {
  final Crop crop;
  final String langCode;

  const _CropTile({required this.crop, required this.langCode});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/advice/${crop.cropId}'),
      borderRadius: AppRadius.cardMain,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.cardMain,
          border: Border.all(color: AppColors.primary.withAlpha(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(crop.emoji, style: const TextStyle(fontSize: 40)),
            const Spacer(),
            Text(
              crop.nameFor(langCode),
              style: AppTypography.h3.copyWith(color: AppColors.bark),
            ),
            Gaps.v3,
            Row(
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                Gaps.h5,
                Text(
                  '${crop.tips.length} conseil${crop.tips.length > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
