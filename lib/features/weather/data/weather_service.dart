import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../domain/entities/weather_day.dart';

/// Service d'accès aux prévisions météo via l'API Open-Meteo.
///
/// Aucune clé API requise (endpoint public). Utilisé pour afficher les
/// prévisions 5 jours sur l'écran d'accueil avec des suggestions d'action
/// agricole pour chaque jour.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fallback Lomé, Togo — utilisé si la géoloc échoue.
  static const double _fallbackLat = 6.1725;
  static const double _fallbackLng = 1.2314;

  /// Récupère la position utilisateur ou retourne Lomé en fallback.
  Future<({double lat, double lng})> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return (lat: _fallbackLat, lng: _fallbackLng);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (lat: _fallbackLat, lng: _fallbackLng);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return (lat: _fallbackLat, lng: _fallbackLng);
    }
  }

  /// Récupère la prévision sur 5 jours (jour courant inclus).
  ///
  /// Throws [Exception] en cas d'erreur réseau.
  Future<List<WeatherDay>> getFiveDayForecast({
    double? lat,
    double? lng,
  }) async {
    final double effectiveLat;
    final double effectiveLng;
    if (lat != null && lng != null) {
      effectiveLat = lat;
      effectiveLng = lng;
    } else {
      final loc = await _getLocation();
      effectiveLat = loc.lat;
      effectiveLng = loc.lng;
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': effectiveLat.toString(),
        'longitude': effectiveLng.toString(),
        'daily':
            'temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode',
        'timezone': 'auto',
        'forecast_days': '5',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Météo indisponible (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) {
      throw Exception('Réponse météo invalide');
    }

    final dates = (daily['time'] as List).cast<String>();
    final tMax = (daily['temperature_2m_max'] as List).cast<num>();
    final tMin = (daily['temperature_2m_min'] as List).cast<num>();
    final precip = (daily['precipitation_sum'] as List).cast<num>();
    final codes = (daily['weathercode'] as List).cast<num>();

    final days = <WeatherDay>[];
    final len = [dates.length, tMax.length, tMin.length, precip.length, codes.length]
        .reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < len; i++) {
      days.add(
        WeatherDay(
          date: DateTime.parse(dates[i]),
          tempMax: tMax[i].toDouble(),
          tempMin: tMin[i].toDouble(),
          precipitationMm: precip[i].toDouble(),
          weatherCode: codes[i].toInt(),
        ),
      );
    }
    return days;
  }
}
