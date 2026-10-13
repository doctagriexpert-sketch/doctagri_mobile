import 'package:flutter/material.dart';

/// Système de border-radius DoctAgri – Variation intentionnelle
///
/// Pas de border-radius uniforme à 20px partout. C'est un red flag IA.
/// Chaque contexte a son propre radius, et certains sont asymétriques.

class AppRadius {
  AppRadius._();

  // Valeurs de base
  static const double xs = 6;
  static const double sm = 9;
  static const double md = 13;
  static const double lg = 18;
  static const double xl = 24;

  // BorderRadius prêts à l'emploi
  static final BorderRadius small = BorderRadius.circular(sm);
  static final BorderRadius medium = BorderRadius.circular(md);
  static final BorderRadius large = BorderRadius.circular(lg);

  // Asymétriques – le vrai détail humain
  // Les cards ont souvent un top plus arrondi que le bottom
  static final BorderRadius cardMain = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg - 3), // légère variation
    bottomLeft: Radius.circular(md),
    bottomRight: Radius.circular(md),
  );

  // Pour les bottom sheets et modals
  static final BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl - 2),
  );

  // Pour les chips et petits éléments
  static final BorderRadius pill = BorderRadius.circular(50);

  // Pour les images dans les cards (arrondi seulement en haut)
  static final BorderRadius imageTop = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg - 3),
  );

  // Message bubbles chat – asymétrie sur les coins
  static final BorderRadius bubbleUser = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(xs), // petit coin pour indiquer la direction
    bottomLeft: Radius.circular(lg),
    bottomRight: Radius.circular(lg),
  );

  static final BorderRadius bubbleBot = BorderRadius.only(
    topLeft: Radius.circular(xs),
    topRight: Radius.circular(lg),
    bottomLeft: Radius.circular(lg),
    bottomRight: Radius.circular(lg),
  );
}
