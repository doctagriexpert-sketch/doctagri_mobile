import 'package:flutter/material.dart';

/// Courbes d'animation DoctAgri – Calme & Professionnel
///
/// Pas de Curves.easeInOut partout. Chaque type d'interaction
/// a sa propre courbe.
///
/// Philosophie: les animations sont au service de l'UX, pas du spectacle.
/// Durées courtes (150-250ms), pas de bounce excessif.

class AppCurves {
  AppCurves._();

  // ══════════════════════════════════════════════════════════════════
  // COURBES PRINCIPALES
  // ══════════════════════════════════════════════════════════════════

  /// Standard – pour la plupart des transitions
  /// Plus rapide au départ, ralentit en fin
  static const Curve standard = Curves.easeOutCubic;

  /// Subtile – pour les hovers, changements d'état légers
  static const Curve subtle = Curves.easeOut;

  /// Emphasis – pour les éléments qui apparaissent
  /// Léger overshoot contrôlé (1.5% max)
  static const Curve emphasis = Cubic(0.34, 1.02, 0.64, 1);

  /// Decelerate – pour les éléments qui disparaissent
  static const Curve decelerate = Curves.decelerate;

  // ══════════════════════════════════════════════════════════════════
  // DURÉES STANDARD
  // ══════════════════════════════════════════════════════════════════

  /// Micro-interaction (hover, press feedback)
  static const Duration fast = Duration(milliseconds: 120);

  /// Standard (transitions d'états)
  static const Duration medium = Duration(milliseconds: 200);

  /// Pour les éléments plus complexes (modals, pages)
  static const Duration slow = Duration(milliseconds: 280);

  /// Scroll to position, etc
  static const Duration navigation = Duration(milliseconds: 350);
}

/// Helper pour créer des animations simples
/// Évite le boilerplate AnimationController
class TapAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double pressedOpacity;

  const TapAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97, // très subtil, pas 0.9
    this.pressedOpacity = 0.85,
  });

  @override
  State<TapAnimation> createState() => _TapAnimationState();
}

class _TapAnimationState extends State<TapAnimation> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppCurves.fast,
        curve: AppCurves.subtle,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1.0,
          duration: AppCurves.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
