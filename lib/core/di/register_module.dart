import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../features/diagnosis/domain/entities/diagnosis_result.dart';

@module
abstract class RegisterModule {
  Future<Box<T>> _openEncryptedBox<T>(String name) async {
    const secureStorage = FlutterSecureStorage();
    final contains = await secureStorage.containsKey(key: 'hive_key');
    if (!contains) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(key: 'hive_key', value: base64UrlEncode(key));
    }
    final keyString = await secureStorage.read(key: 'hive_key');
    final encryptionKey = base64Url.decode(keyString!);
    return Hive.openBox<T>(
      name,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  @preResolve
  @Named('diagnosisBox')
  Future<Box<DiagnosisResult>> get diagnosisBox =>
      _openEncryptedBox<DiagnosisResult>('diagnosis_history');

  @preResolve
  @Named('validationBox')
  Future<Box<String>> get validationBox =>
      _openEncryptedBox<String>('validation_requests');

  @preResolve
  @Named('syncBox')
  Future<Box<String>> get syncBox => _openEncryptedBox<String>('sync_queue');
}
