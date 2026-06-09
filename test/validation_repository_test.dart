import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:doctagri/features/diagnosis/data/repositories/validation_repository_impl.dart';
import 'package:doctagri/features/diagnosis/domain/entities/validation_request.dart';

void main() {
  late Box<String> box;
  late ValidationRepositoryImpl repo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('validation_repo_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('test_validation');
    repo = ValidationRepositoryImpl(box: box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  int counter = 0;

  ValidationRequest makeRequest({String status = 'pending'}) {
    counter++;
    return ValidationRequest(
      id: 'req-$counter-${DateTime.now().microsecondsSinceEpoch}',
      imagePath: '/tmp/photo.jpg',
      predictedLabel: 'Tomato___Late_Blight',
      confidence: 0.42,
      requestedAt: DateTime.now(),
      status: status,
    );
  }

  group('ValidationRepositoryImpl', () {
    test('submitValidation stocke et getPendingValidations retrouve', () async {
      final request = makeRequest();
      await repo.submitValidation(request);

      final pending = await repo.getPendingValidations();

      expect(pending.length, 1);
      expect(pending.first.id, request.id);
      expect(pending.first.predictedLabel, 'Tomato___Late_Blight');
      expect(pending.first.confidence, 0.42);
      expect(pending.first.status, 'pending');
    });

    test('markAsSynced passe le status à synced', () async {
      final request = makeRequest();
      await repo.submitValidation(request);

      await repo.markAsSynced(request.id);

      final pending = await repo.getPendingValidations();
      expect(pending, isEmpty);

      // Vérifie que le status en base est bien 'synced'
      final raw = box.get(request.id);
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      expect(data['status'], 'synced');
    });

    test('getPendingCount retourne le bon nombre', () async {
      await repo.submitValidation(makeRequest());
      await repo.submitValidation(makeRequest());
      final synced = makeRequest();
      await repo.submitValidation(synced);
      await repo.markAsSynced(synced.id);

      final count = await repo.getPendingCount();
      expect(count, 2);
    });
  });
}
