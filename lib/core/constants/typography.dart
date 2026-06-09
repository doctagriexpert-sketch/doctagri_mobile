import 'package:flutter/material.dart';
import 'colors.dart';

/// Typographie DoctAgri – Sans-Serif (Roboto)
///
/// Mode clair : texte sombre sur fond clair par défaut.
/// Variantes "Light" disponibles pour texte blanc sur fonds colorés.

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Roboto';

  // Couleur de texte principale (sombre)
  static const Color _textPrimary = Color(0xFF2D3142);
  static const Color _textSecondary = Color(0xFF6B7280);

  // ══════════════════════════════════════════════════════════════════
  // HEADINGS
  // ══════════════════════════════════════════════════════════════════

  /// Display – titres principaux
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.5,
    color: _textPrimary,
  );

  /// H1 – Titres de page
  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: 0.15,
    color: _textPrimary,
  );

  /// H2 – Sections
  static const TextStyle h2 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.1,
    color: _textPrimary,
  );

  /// H3 – Sous-sections, card titles
  static TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.38,
    color: _textPrimary.withAlpha(230),
  );

  // ══════════════════════════════════════════════════════════════════
  // BODY TEXT
  // ══════════════════════════════════════════════════════════════════

  /// Body – Texte principal
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.62,
    color: _textPrimary,
  );

  /// Body secondary – Moins important
  static TextStyle bodySecondary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.62,
    color: _textSecondary,
  );

  /// Caption – Infos secondaires, metadata
  static TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: _textSecondary,
  );

  /// Small – Labels, badges
  static const TextStyle small = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.38,
    letterSpacing: 0.3,
    color: _textPrimary,
  );

  // ══════════════════════════════════════════════════════════════════
  // VARIANTES CLAIRES (texte blanc sur fonds colorés)
  // ══════════════════════════════════════════════════════════════════

  static const TextStyle displayLight = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.5,
    color: Colors.white,
  );

  static const TextStyle h1Light = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: 0.15,
    color: Colors.white,
  );

  static const TextStyle h2Light = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.1,
    color: Colors.white,
  );

  static TextStyle h3Light = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.38,
    color: Colors.white.withAlpha(230),
  );

  static const TextStyle bodyLight = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.62,
    color: Colors.white,
  );

  static TextStyle captionLight = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Colors.white.withAlpha(178),
  );

  // ══════════════════════════════════════════════════════════════════
  // COMPAT — anciens noms
  // ══════════════════════════════════════════════════════════════════

  /// Ancien: pour texte sur fond clair (maintenant c'est le défaut)
  static TextStyle bodyDark = body;
  static TextStyle h2Dark = h2;

  /// Texte d'accent (prix, CTA)
  static TextStyle priceTag = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.primary,
  );
}
