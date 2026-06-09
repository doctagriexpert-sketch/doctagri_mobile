import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/entities/weather_day.dart';
import '../providers/weather_provider.dart';

/// Widget d'affichage de la prévision météo 5 jours pour l'écran d'accueil.
///
/// Se charge automatiquement au montage. Affiche un état chargement, erreur
/// (avec bouton réessayer), ou la liste des 5 jours avec action agricole.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WeatherProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardMain,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(provider),
          Gaps.v11,
          _buildBody(provider),
        ],
      ),
    );
  }

  Widget _buildHeader(WeatherProvider provider) {
    return Row(
      children: [
        Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 22),
        Gaps.h7,
        Text('Météo 5 jours', style: AppTypography.h3),
        const Spacer(),
        if (provider.isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => provider.refresh(),
          ),
      ],
    );
  }

  Widget _buildBody(WeatherProvider provider) {
    switch (provider.status) {
      case WeatherStatus.idle:
      case WeatherStatus.loading:
        return _buildSkeleton();
      case WeatherStatus.error:
        return _buildError(provider);
      case WeatherStatus.loaded:
        return _buildForecast(provider.days);
    }
  }

  Widget _buildSkeleton() {
    return SizedBox(
      height: 120,
      child: Row(
        children: List.generate(
          5,
          (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.fog.withAlpha(40),
                borderRadius: AppRadius.small,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(WeatherProvider provider) {
    return Column(
      children: [
        Icon(Icons.cloud_off, color: AppColors.danger, size: 32),
        Gaps.v7,
        Text(
          'Météo indisponible',
          style: TextStyle(fontSize: 13, color: AppColors.bark),
        ),
        Gaps.v7,
        TextButton.icon(
          onPressed: () => provider.refresh(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Réessayer'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildForecast(List<WeatherDay> days) {
    return Column(
      children: [
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _DayChip(day: days[i], isToday: i == 0),
          ),
        ),
        if (days.isNotEmpty) ...[
          Gaps.v11,
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20),
              borderRadius: AppRadius.small,
              border: Border.all(color: AppColors.accent.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
                Gaps.h7,
                Expanded(
                  child: Text(
                    "Aujourd'hui : ${days.first.dailyAction}",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final WeatherDay day;
  final bool isToday;

  const _DayChip({required this.day, required this.isToday});

  IconData _iconFor(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_queue_rounded;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.grain_rounded;
    if (code <= 77) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.umbrella_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  Color _colorFor(int code) {
    if (code >= 95) return AppColors.danger;
    if (code >= 61) return AppColors.primary;
    if (code == 0) return AppColors.accent;
    return AppColors.fog;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(day.weatherCode);
    return Tooltip(
      message: '${day.conditionLabel}\n${day.dailyAction}',
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primary.withAlpha(15) : Colors.transparent,
          borderRadius: AppRadius.small,
          border: Border.all(
            color: isToday
                ? AppColors.primary.withAlpha(80)
                : AppColors.fog.withAlpha(80),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isToday ? "Auj." : day.shortDayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.primary : AppColors.bark,
              ),
            ),
            Icon(_iconFor(day.weatherCode), color: color, size: 24),
            Text(
              '${day.tempMax.round()}°',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.bark,
              ),
            ),
            Text(
              '${day.tempMin.round()}°',
              style: TextStyle(fontSize: 11, color: AppColors.fog),
            ),
          ],
        ),
      ),
    );
  }
}
