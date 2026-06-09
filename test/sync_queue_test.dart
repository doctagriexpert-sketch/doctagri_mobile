import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:doctagri/core/services/sync_queue.dart';

void main() {
  late Box<String> box;
  late SyncQueue syncQueue;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_queue_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('test_sync_queue');
    syncQueue = SyncQueue(box: box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SyncItem makeItem({
    String type = 'diagnosis',
    String status = 'pending',
    int retryCount = 0,
    DateTime? createdAt,
  }) {
    return SyncItem(
      type: type,
      data: {'label': 'Tomato___Early_Blight', 'confidence': 0.95},
      imagePath: '/tmp/test.jpg',
      status: status,
      retryCount: retryCount,
      createdAt: createdAt,
    );
  }

  group('SyncQueue', () {
    test('enqueue ajoute un item et getPending le retrouve', () async {
      final item = makeItem();
      await syncQueue.enqueue(item);

      final pending = await syncQueue.getPending();

      expect(pending.length, 1);
      expect(pending.first.id, item.id);
      expect(pending.first.type, 'diagnosis');
      expect(pending.first.status, 'pending');
      expect(pending.first.imagePath, '/tmp/test.jpg');
    });

    test('markCompleted retire l\'item de la liste pending', () async {
      final item = makeItem();
      await syncQueue.enqueue(item);

      await syncQueue.markCompleted(item.id);

      final pending = await syncQueue.getPending();
      expect(pending, isEmpty);

      // Vérifie que l'item est toujours en box mais avec status completed
      final raw = box.get(item.id);
      expect(raw, isNotNull);
      final stored = jsonDecode(raw!) as Map<String, dynamic>;
      expect(stored['status'], 'completed');
    });

    test('markFailed incrémente retryCount et garde status pending', () async {
      final item = makeItem();
      await syncQueue.enqueue(item);

      await syncQueue.markFailed(item.id);

      final pending = await syncQueue.getPending();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
      expect(pending.first.status, 'pending');

      // Deuxième échec
      await syncQueue.markFailed(item.id);
      final pending2 = await syncQueue.getPending();
      expect(pending2.first.retryCount, 2);
    });

    test('pendingCount retourne le bon nombre', () async {
      await syncQueue.enqueue(makeItem());
      await syncQueue.enqueue(makeItem());
      final completed = makeItem();
      await syncQueue.enqueue(completed);
      await syncQueue.markCompleted(completed.id);

      final count = await syncQueue.pendingCount;
      expect(count, 2);
    });

    test('getPending retourne les items triés FIFO par createdAt', () async {
      final old = makeItem(createdAt: DateTime(2024, 1, 1));
      final recent = makeItem(createdAt: DateTime(2024, 6, 15));
      // Insérer dans l'ordre inverse
      await syncQueue.enqueue(recent);
      await syncQueue.enqueue(old);

      final pending = await syncQueue.getPending();

      expect(pending.length, 2);
      expect(pending.first.id, old.id); // Le plus ancien en premier
      expect(pending.last.id, recent.id);
    });

    test('cleanup supprime les items completed de plus de 7 jours', () async {
      // Item complété il y a 10 jours
      final oldItem = makeItem(
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      await syncQueue.enqueue(oldItem);
      await syncQueue.markCompleted(oldItem.id);

      // Item complété aujourd'hui (doit survivre)
      final recentItem = makeItem();
      await syncQueue.enqueue(recentItem);
      await syncQueue.markCompleted(recentItem.id);

      // Item pending (ne doit jamais être supprimé)
      final pendingItem = makeItem();
      await syncQueue.enqueue(pendingItem);

      await syncQueue.cleanup();

      // L'ancien completed est supprimé
      expect(box.containsKey(oldItem.id), false);
      // Le récent completed et le pending restent
      expect(box.containsKey(recentItem.id), true);
      expect(box.containsKey(pendingItem.id), true);
    });
  });
}
