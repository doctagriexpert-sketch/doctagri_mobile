import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android persists and uploads this record without a running Flutter engine.
class InstallationRegistrationService {
  static const channel = MethodChannel('doctagri/installations');

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      // Call even without configuration: first-open identity is saved offline.
      await channel.invokeMethod<void>('register', {
        'url': const String.fromEnvironment('SUPABASE_URL'),
        'anonKey': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      });
    } on PlatformException {
      if (kDebugMode) {
        debugPrint('Installation registration unavailable');
      }
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('Installation registration plugin unavailable');
      }
    }
  }
}
