import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/radius.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/curves.dart';

/// Card tactile avec micro-animation de feedback
///
/// Différent des GestureDetector + Container basiques:
/// - Animation de pression subtile (scale 0.97, pas 0.9)
/// - Border-radius asymétriques selon le variant
/// - Ombre contextuelle

enum CardVariant {
  flat,
  elevated,
  outlined,
}

class TactileCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final CardVariant variant;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const TactileCard({
    super.key,
    required this.child,
    this.onTap,
    this.variant = CardVariant.elevated,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  State<TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<TactileCard> {
  bool _pressing = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _pressing = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _pressing = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _pressing = false);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.card;
    final radius = widget.borderRadius ?? AppRadius.cardMain;
    final contentPadding = widget.padding ?? Spacing.cardPadding;

    return GestureDetector(
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: AppCurves.fast,
        curve: AppCurves.subtle,
        child: AnimatedContainer(
          duration: AppCurves.fast,
          curve: AppCurves.subtle,
          padding: contentPadding,
          decoration: BoxDecoration(
            color: _pressing ? bgColor.withAlpha(220) : bgColor,
            borderRadius: radius,
            border: widget.variant == CardVariant.outlined
                ? Border.all(color: AppColors.fog.withAlpha(100), width: 1)
                : null,
            boxShadow: _buildShadow(),
          ),
          child: widget.child,
        ),
      ),
    );
  }

  List<BoxShadow>? _buildShadow() {
    if (widget.variant != CardVariant.elevated) return null;

    return [
      BoxShadow(
        color: Colors.black.withAlpha(_pressing ? 10 : 20),
        blurRadius: 8,
        offset: Offset(0, _pressing ? 2 : 4),
      ),
    ];
  }
}

/// Card info simple pour les sections type "Conseils"
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accentColor;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;

    return TactileCard(
      onTap: onTap,
      backgroundColor: accent.withAlpha(230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          Gaps.v11,
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          Gaps.v5,
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          Gaps.v7,
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withAlpha(140),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
