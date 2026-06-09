import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/typography.dart';
import '../../../../core/constants/curves.dart';
import '../../../../core/ml/model_manager.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../shared/widgets/tactile_card.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../weather/presentation/providers/weather_provider.dart';
import '../../../weather/presentation/widgets/weather_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isOffline = true;
  bool _modelReady = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
    _modelReady = ModelManager.instance.isReady;
    if (!_modelReady) {
      // Les modèles se chargent en background — on attend la fin pour
      // mettre à jour l'indicateur sans bloquer l'UI.
      ModelManager.instance.initialize().then((_) {
        if (mounted) setState(() => _modelReady = ModelManager.instance.isReady);
      });
    }
  }

  void _setupConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) _handleConnectivityChange(results);
    } catch (_) {}

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langService = context.watch<LanguageService>();
    final voiceService = context.watch<VoiceService>();

    return ChangeNotifierProvider(
      create: (_) => WeatherProvider(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: Spacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(langService),
                Gaps.v21,
                _buildVoiceQuickAccess(context, voiceService, langService),
                Gaps.v21,
                const WeatherCard(),
                Gaps.v21,
                _buildScanSection(context, langService),
                Gaps.v21,
                _buildQuickActions(context, langService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting(LanguageService langService) {
    final hour = DateTime.now().hour;
    if (hour < 12) return langService.t('greeting_morning');
    if (hour < 18) return langService.t('greeting_afternoon');
    return langService.t('greeting_evening');
  }

  Widget _buildHeader(LanguageService langService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getGreeting(langService), style: AppTypography.display),
              Gaps.v5,
              Text(
                langService.t('home_subtitle'),
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
        ),
        Gaps.h11,
        _buildConnectionBadge(langService),
      ],
    );
  }

  Widget _buildConnectionBadge(LanguageService langService) {
    return AnimatedContainer(
      duration: AppCurves.medium,
      curve: AppCurves.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: _isOffline
            ? AppColors.fog.withAlpha(50)
            : AppColors.healthy.withAlpha(25),
        borderRadius: AppRadius.pill,
        border: _isOffline
            ? Border.all(color: AppColors.fog.withAlpha(80))
            : Border.all(color: AppColors.healthy.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOffline ? Icons.wifi_off : Icons.wifi,
            color: _isOffline ? AppColors.fog : AppColors.healthy,
            size: 16,
          ),
          Gaps.h7,
          Text(
            _isOffline ? langService.t('offline') : langService.t('online'),
            style: TextStyle(
              color: _isOffline ? AppColors.bark : AppColors.healthy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceQuickAccess(
    BuildContext context,
    VoiceService voiceService,
    LanguageService langService,
  ) {
    return GestureDetector(
      onTap: () async {
        if (voiceService.isListening) {
          await voiceService.stopListening();
        } else {
          await voiceService.startListening(
            onResult: (text) {
              if (text.trim().isNotEmpty) {
                context.push('/camera');
              }
            },
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: voiceService.isListening
                ? [AppColors.accent, AppColors.accent.withAlpha(200)]
                : [AppColors.secondary, AppColors.secondary.withAlpha(200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.cardMain,
          boxShadow: [
            BoxShadow(
              color:
                  (voiceService.isListening
                          ? AppColors.accent
                          : AppColors.secondary)
                      .withAlpha(50),
              blurRadius: voiceService.isListening ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                shape: BoxShape.circle,
                boxShadow: voiceService.isListening
                    ? [
                        BoxShadow(
                          color: Colors.white.withAlpha(60),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                voiceService.isListening
                    ? Icons.hearing_rounded
                    : Icons.mic_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            Gaps.h14,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voiceService.isListening
                        ? langService.t('voice_listening')
                        : langService.t('voice_input'),
                    style: AppTypography.h3Light,
                  ),
                  Gaps.v3,
                  Text(
                    langService.t('assistant_subtitle'),
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            LanguageSelector(
              currentLanguage: langService.languageCode,
              onLanguageChanged: (code) {
                final lang = switch (code) {
                  'ee' => AppLanguage.ewe,
                  'kab' => AppLanguage.kabye,
                  _ => AppLanguage.french,
                };
                langService.setLanguage(lang);
                voiceService.setLanguage(code);
              },
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanSection(BuildContext context, LanguageService langService) {
    return Column(
      children: [
        TapAnimation(
          onTap: () => context.push('/camera'),
          pressedScale: 0.97,
          child: _buildScanCard(langService),
        ),
        if (!_modelReady) ...[
          Gaps.v7,
          _buildModelLoadingBar(),
        ],
      ],
    );
  }

  Widget _buildModelLoadingBar() {
    return Row(
      children: [
        const Icon(Icons.memory_rounded, size: 13, color: AppColors.fog),
        Gaps.h7,
        Expanded(
          child: LinearProgressIndicator(
            backgroundColor: AppColors.fog.withAlpha(30),
            color: AppColors.primary.withAlpha(160),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Gaps.h7,
        Text(
          'IA en cours de chargement…',
          style: TextStyle(fontSize: 11, color: AppColors.fog),
        ),
      ],
    );
  }

  Widget _buildScanCard(LanguageService langService) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.cardMain,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(60),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            Gaps.h21,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langService.t('scan_plant'),
                    style: AppTypography.h2Light,
                  ),
                  Gaps.v5,
                  Text(
                    langService.t('scan_description'),
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withAlpha(150),
              size: 20,
            ),
          ],
        ),
    );
  }

  Widget _buildQuickActions(BuildContext context, LanguageService langService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(langService.t('quick_actions'), style: AppTypography.h3),
        Gaps.v11,
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.history_rounded,
                title: langService.t('history'),
                subtitle: langService.t('diagnostic'),
                accentColor: AppColors.primary,
                onTap: () => context.push('/history'),
              ),
            ),
            Gaps.h11,
            Expanded(
              child: InfoCard(
                icon: Icons.menu_book_rounded,
                title: 'Conseils',
                subtitle: 'Par culture',
                accentColor: AppColors.secondary,
                onTap: () => context.push('/advice'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
