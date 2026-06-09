import 'package:flutter/foundation.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._();
  factory TelemetryService() => _instance;
  TelemetryService._();

  bool _initialized = false;

  Future<void> initialize({
    required String sentryDsn,
    String? environment,
    String? release,
  }) async {
    if (_initialized) return;
    _initialized = true;
    if (kDebugMode) {
      debugPrint('[Telemetry] Initialized (Sentry DSH hidden)');
    }
  }

  Future<void> captureException(
    dynamic error, {
    dynamic stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) {
      debugPrint('[Telemetry] Exception: $error');
      if (extra != null) debugPrint('[Telemetry] Extra: $extra');
    }
  }

  Future<void> captureMessage(
    String message, {
    String level = 'info',
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) {
      debugPrint('[Telemetry][$level] $message');
    }
  }

  Future<void> setUser({
    required String id,
    String? email,
    String? username,
    Map<String, dynamic>? extra,
  }) async {
    if (kDebugMode) {
      debugPrint('[Telemetry] User set: $id');
    }
  }

  Future<void> addBreadcrumb(String message, {String? category}) async {
    if (kDebugMode) {
      debugPrint('[Telemetry] Breadcrumb[$category]: $message');
    }
  }

  Future<void> trackEvent(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {
    if (kDebugMode) {
      debugPrint('[Telemetry] Event: $eventName');
      if (properties != null) debugPrint('[Telemetry] Props: $properties');
    }
  }
}
