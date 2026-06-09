/// Entité représentant les données météo d'un jour.
///
/// Les codes météo suivent la convention WMO utilisée par Open-Meteo.
/// Référence : https://open-meteo.com/en/docs#weathervariables
class WeatherDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double precipitationMm;
  final int weatherCode;

  const WeatherDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationMm,
    required this.weatherCode,
  });

  /// Libellé court de la condition principale (français).
  String get conditionLabel {
    if (weatherCode == 0) return 'Ensoleillé';
    if (weatherCode <= 3) return 'Nuageux';
    if (weatherCode <= 48) return 'Brouillard';
    if (weatherCode <= 57) return 'Bruine';
    if (weatherCode <= 67) return 'Pluie';
    if (weatherCode <= 77) return 'Neige';
    if (weatherCode <= 82) return 'Averses';
    if (weatherCode <= 86) return 'Neige';
    if (weatherCode >= 95) return 'Orage';
    return 'Variable';
  }

  /// Retourne une suggestion d'action agricole basée sur la météo du jour.
  ///
  /// Règles métiers :
  /// - Précipitation > 5mm → reporter les traitements foliaires (lessivage)
  /// - Tmax > 32°C → irriguer tôt le matin (stress hydrique)
  /// - Code orage (95-99) → sécuriser les cultures fragiles
  /// - Sinon → conditions favorables au travail au champ
  String get dailyAction {
    if (weatherCode >= 95) {
      return 'Sécuriser les cultures fragiles (orage prévu)';
    }
    if (precipitationMm > 5) {
      return 'Reporter les traitements foliaires';
    }
    if (tempMax > 32) {
      return 'Irriguer tôt le matin';
    }
    if (precipitationMm > 0.5 && precipitationMm <= 5) {
      return 'Pluies légères — favorable aux semis';
    }
    return 'Conditions favorables au champ';
  }

  /// Retourne le nom court du jour (Lun, Mar, …) en français.
  String get shortDayName {
    const names = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return names[(date.weekday - 1) % 7];
  }
}
