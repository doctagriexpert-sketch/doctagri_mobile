import 'package:doctagri/core/services/installation_registration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      InstallationRegistrationService.channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(
      InstallationRegistrationService.channel,
      null,
    );
  });

  test(
    'records first opening even when backend configuration is absent',
    () async {
      await InstallationRegistrationService.initialize();
      expect(calls.single.method, 'register');
      expect(calls.single.arguments, {'url': '', 'anonKey': ''});
    },
  );

  test('does not invoke Android worker on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await InstallationRegistrationService.initialize();
    expect(calls, isEmpty);
  });

  test(
    'native registration failure does not prevent application startup',
    () async {
      messenger.setMockMethodCallHandler(
        InstallationRegistrationService.channel,
        (_) async {
          throw PlatformException(code: 'disk_unavailable');
        },
      );
      await expectLater(
        InstallationRegistrationService.initialize(),
        completes,
      );
    },
  );
}
