import 'package:flutter/foundation.dart';

import '../../data/weather_service.dart';
import '../../domain/entities/weather_day.dart';

enum WeatherStatus { idle, loading, loaded, error }

/// Provider météo — charge la prévision 5 jours et expose l'état UI.
class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;

  WeatherProvider({WeatherService? service})
    : _service = service ?? WeatherService();

  WeatherStatus _status = WeatherStatus.idle;
  List<WeatherDay> _days = const [];
  String? _errorMessage;

  WeatherStatus get status => _status;
  List<WeatherDay> get days => _days;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == WeatherStatus.loading;
  bool get hasData => _status == WeatherStatus.loaded && _days.isNotEmpty;

  /// Charge la prévision. Si déjà chargée, ne recharge pas sauf [force].
  Future<void> load({bool force = false}) async {
    if (!force && _status == WeatherStatus.loaded) return;
    if (_status == WeatherStatus.loading) return;

    _status = WeatherStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _days = await _service.getFiveDayForecast();
      _status = WeatherStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = WeatherStatus.error;
    }
    notifyListeners();
  }

  /// Rafraîchit (équivalent à load(force: true)).
  Future<void> refresh() => load(force: true);
}
