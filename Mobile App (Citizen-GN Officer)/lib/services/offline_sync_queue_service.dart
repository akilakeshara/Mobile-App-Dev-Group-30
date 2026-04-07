import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_data_encryption_service.dart';

class OfflineSyncQueueService {
  OfflineSyncQueueService._();

  static final OfflineSyncQueueService instance = OfflineSyncQueueService._();

  static const String _table = 'sync_queue';
  static const int _maxRetryCount = 10;
  static const String _encryptedPayloadPrefix = 'enc::';

  Database? _db;
  FirebaseFirestore? _firestore;
  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isSyncing = false;
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  Future<void> initialize(FirebaseFirestore firestore) async {
    if (_isInitialized) return;

    _firestore = firestore;
    await LocalDataEncryptionService.instance.initialize();
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'govease_offline_sync.db');

    _db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operationType TEXT NOT NULL,
            collectionName TEXT NOT NULL,
            documentId TEXT NOT NULL,
            payload TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            retryCount INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    await _rotateEncryptionIfDue();

    _isInitialized = true;
    await _refreshPendingCount();

    // Retry queued writes periodically; once connectivity is restored,
    // pending writes are pushed to Firestore automatically.
    _syncTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => flushPendingWrites(),
    );

    await flushPendingWrites();
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    await _db?.close();
    _db = null;
    _isInitialized = false;
    _isSyncing = false;
    pendingCount.value = 0;
    syncing.value = false;
  }

  Future<int> getPendingCount() async {
    final db = _db;
    if (db == null) return 0;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_table'),
        ) ??
        0;
  }

  Future<int> getActiveEncryptionKeyVersion() {
    return LocalDataEncryptionService.instance.getActiveKeyVersion();
  }

  Future<int> rotateEncryptionKeyAndReencryptQueue() async {
    final db = _db;
    if (db == null) return 0;

    await LocalDataEncryptionService.instance.rotateActiveKey();

    final rows = await db.query(_table, columns: ['id', 'payload']);
    var migratedCount = 0;

    for (final row in rows) {
      final id = row['id'] as int;
      final payloadRaw = (row['payload'] ?? '{}').toString();

      try {
        final payload = await _decodePayload(payloadRaw);
        final reEncryptedPayload = await _encodePayload(payload);
        await db.update(
          _table,
          {'payload': reEncryptedPayload},
          where: 'id = ?',
          whereArgs: [id],
        );
        migratedCount++;
      } catch (e) {
        debugPrint(
          'Failed to re-encrypt queued payload row $id during key rotation: $e',
        );
      }
    }

    return migratedCount;
  }

  Future<void> _rotateEncryptionIfDue() async {
    final shouldRotate = await LocalDataEncryptionService.instance
        .shouldRotateKey();
    if (!shouldRotate) return;

    final migrated = await rotateEncryptionKeyAndReencryptQueue();
    debugPrint(
      'Local encryption key rotated automatically. Re-encrypted queue rows: $migrated',
    );
  }

  Future<void> enqueueSet({
    required String collectionName,
    required String documentId,
    required Map<String, dynamic> payload,
    bool merge = false,
  }) async {
    await _enqueue(
      operationType: merge ? 'set_merge' : 'set',
      collectionName: collectionName,
      documentId: documentId,
      payload: payload,
    );
  }

  Future<void> enqueueUpdate({
    required String collectionName,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    await _enqueue(
      operationType: 'update',
      collectionName: collectionName,
      documentId: documentId,
      payload: payload,
    );
  }

  Future<void> _enqueue({
    required String operationType,
    required String collectionName,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final db = _db;
    if (db == null) return;

    final encodedPayload = await _encodePayload(payload);

    await db.insert(_table, {
      'operationType': operationType,
      'collectionName': collectionName,
      'documentId': documentId,
      'payload': encodedPayload,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });

    await _refreshPendingCount();
  }

  Future<void> flushPendingWrites() async {
    if (_isSyncing) return;

    final db = _db;
    final firestore = _firestore;
    if (db == null || firestore == null) return;

    _isSyncing = true;
    syncing.value = true;
    try {
      final rows = await db.query(_table, orderBy: 'id ASC', limit: 50);

      for (final row in rows) {
        final id = row['id'] as int;
        final operationType = (row['operationType'] ?? '').toString();
        final collectionName = (row['collectionName'] ?? '').toString();
        final documentId = (row['documentId'] ?? '').toString();
        final payloadRaw = (row['payload'] ?? '{}').toString();
        final retryCount = (row['retryCount'] as int?) ?? 0;

        try {
          final payload = await _decodePayload(payloadRaw);

          final ref = firestore.collection(collectionName).doc(documentId);

          if (operationType == 'set') {
            await ref.set(payload);
          } else if (operationType == 'set_merge') {
            await ref.set(payload, SetOptions(merge: true));
          } else if (operationType == 'update') {
            await ref.update(payload);
          } else {
            await db.delete(_table, where: 'id = ?', whereArgs: [id]);
            continue;
          }

          await db.delete(_table, where: 'id = ?', whereArgs: [id]);
        } catch (e) {
          final nextRetryCount = retryCount + 1;

          if (nextRetryCount >= _maxRetryCount) {
            await db.delete(_table, where: 'id = ?', whereArgs: [id]);
            debugPrint(
              'Dropping queued write after $_maxRetryCount retries: '
              '$collectionName/$documentId ($operationType)',
            );
            continue;
          }

          await db.update(
            _table,
            {'retryCount': nextRetryCount},
            where: 'id = ?',
            whereArgs: [id],
          );

          // Stop on first network/backend failure and retry in next cycle.
          break;
        }
      }
    } catch (e) {
      debugPrint('Offline sync flush error: $e');
    } finally {
      _isSyncing = false;
      syncing.value = false;
      await _refreshPendingCount();
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      pendingCount.value = await getPendingCount();
    } catch (e) {
      debugPrint('Failed to refresh pending sync count: $e');
    }
  }

  Future<String> _encodePayload(Map<String, dynamic> payload) async {
    final payloadJson = jsonEncode(payload);
    final encrypted = await LocalDataEncryptionService.instance.encryptText(
      payloadJson,
    );
    return '$_encryptedPayloadPrefix$encrypted';
  }

  Future<Map<String, dynamic>> _decodePayload(String storedPayload) async {
    if (storedPayload.startsWith(_encryptedPayloadPrefix)) {
      final encryptedBody = storedPayload.substring(
        _encryptedPayloadPrefix.length,
      );
      final decrypted = await LocalDataEncryptionService.instance.decryptText(
        encryptedBody,
      );
      return Map<String, dynamic>.from(
        jsonDecode(decrypted) as Map<String, dynamic>,
      );
    }

    // Backward compatibility for queue rows stored before encryption support.
    return Map<String, dynamic>.from(
      jsonDecode(storedPayload) as Map<String, dynamic>,
    );
  }
}
