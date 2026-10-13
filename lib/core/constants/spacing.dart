import 'package:flutter/material.dart';

/// Système de spacing DoctAgri – Échelle Fibonacci-like
///
/// Pourquoi pas des multiples de 4/8 ? Parce que ça sent le template.
/// Cette échelle crée un rythme visuel plus organique.
///
/// Astuce: utiliser les helpers Gaps.v() et Gaps.h() dans le code
/// pour éviter les SizedBox répétitifs.

class Spacing {
  Spacing._();

  // Échelle principale (Fibonacci modifié pour le design)
  static const double xs = 5;
  static const double sm = 7;
  static const double md = 11;
  static const double base = 14; // le "16" remplacé
  static const double lg = 21;
  static const double xl = 34;
  static const double xxl = 55;

  // Alias pour les paddings de page (légèrement asymétriques)
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(18, 21, 18, 17);
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(14, 11, 14, 13);
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 11,
    vertical: 7,
  );
}

/// Helpers pour espacements récurrents
///
/// Usage: Gaps.v14 au lieu de SizedBox(height: 14)
class Gaps {
  Gaps._();

  // Verticaux
  static const SizedBox v3 = SizedBox(height: 3);
  static const SizedBox v5 = SizedBox(height: 5);
  static const SizedBox v7 = SizedBox(height: 7);
  static const SizedBox v11 = SizedBox(height: 11);
  static const SizedBox v14 = SizedBox(height: 14);
  static const SizedBox v21 = SizedBox(height: 21);
  static const SizedBox v34 = SizedBox(height: 34);
  static const SizedBox v55 = SizedBox(height: 55);

  // Horizontaux
  static const SizedBox h5 = SizedBox(width: 5);
  static const SizedBox h7 = SizedBox(width: 7);
  static const SizedBox h11 = SizedBox(width: 11);
  static const SizedBox h14 = SizedBox(width: 14);
  static const SizedBox h21 = SizedBox(width: 21);
  static const SizedBox h34 = SizedBox(width: 34);

  // Pour les cas où on a besoin de valeurs custom dans une row/column
  static SizedBox vertical(double height) => SizedBox(height: height);
  static SizedBox horizontal(double width) => SizedBox(width: width);
}
