import 'package:flutter/material.dart';

/// Palette DoctAgri — Charte graphique officielle
///
/// Bleu Foncé (#1A368E) — "Doct" : primaire, confiance, expertise
/// Vert Éclatant (#7ED92A) — "Agri" : accent, CTA, vitalité
/// Vert Foncé (#2D5A27) — détails, icônes secondaires
/// Gris Clair (#D1D3D4) — neutres, bordures, texte secondaire

class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════════
  // SOURCE COLORS – Charte DoctAgri
  // ══════════════════════════════════════════════════════════════════

  /// Bleu foncé – Couleur primaire "Doct"
  static const Color _primarySource = Color(0xFF1A368E);

  /// Vert foncé – Variante secondaire
  static const Color _secondarySource = Color(0xFF2D5A27);

  /// Vert éclatant – Accent, CTA "Agri"
  static const Color _accentSource = Color(0xFF7ED92A);

  /// Gris clair – Neutres, bordures
  static const Color _highlightSource = Color(0xFFD1D3D4);

  // ══════════════════════════════════════════════════════════════════
  // PALETTE SÉMANTIQUE
  // ══════════════════════════════════════════════════════════════════

  // Primaires
  static const Color primary = _primarySource; // Bleu foncé #1A368E
  static const Color secondary = _secondarySource; // Vert foncé #2D5A27
  static const Color accent = _accentSource; // Vert éclatant #7ED92A

  // Neutres
  static const Color soil = Color(0xFF0F2259); // Bleu profond (dark variant)
  static const Color parchment = Color(0xFFFFFFFF); // Blanc
  static const Color bark = Color(0xFF2D3142); // Texte principal sombre
  static const Color fog = _highlightSource; // Gris clair

  // États sémantiques
  static const Color healthy = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);

  // ══════════════════════════════════════════════════════════════════
  // ALIAS BACKWARDS COMPAT
  // ══════════════════════════════════════════════════════════════════

  static const Color primaryGreen = accent;
  static const Color darkGreen = secondary;
  static const Color lightGreen = Color(0xFFA8E86B);
  static const Color sage = lightGreen;
  static const Color yellow = accent;
  static const Color yellowAccent = Color(0xFFB5F05A);
  static const Color cardBrown = soil;
  static const Color cardGray = parchment;
  static const Color offlineGray = fog;

  // ══════════════════════════════════════════════════════════════════
  // MODE CLAIR — Surfaces
  // ══════════════════════════════════════════════════════════════════

  static const Color surface = Color(0xFFF5F7FA); // Fond principal
  static const Color card = Color(0xFFFFFFFF); // Cards
  static const Color elevated = Color(0xFFF0F2F5); // Surfaces élevées
}
