import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalDataEncryptionService {
  LocalDataEncryptionService._();

  static final LocalDataEncryptionService instance =
      LocalDataEncryptionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _legacyKeyStorageName = 'govease_local_db_key_v1';
  static const _keyStoragePrefix = 'govease_local_db_key_v';
  static const _activeVersionStorageName =
      'govease_local_db_active_key_version';
  static const _lastRotationAtStorageName =
      'govease_local_db_key_last_rotated_at';
  static const int _defaultActiveKeyVersion = 2;
  static const int _rotationIntervalDays = 90;
  static const String _encryptionAlgorithmName = 'AES_GCM_256';
  static const int _expectedNonceLength = 12;
  static const int _expectedMacLength = 16;

  final AesGcm _algorithm = AesGcm.with256bits();

  final Map<int, SecretKey> _keysByVersion = <int, SecretKey>{};
  int? _activeKeyVersion;
  Future<void>? _initializeFuture;

  Future<void> initialize() async {
    if (_activeKeyVersion != null &&
        _keysByVersion.containsKey(_activeKeyVersion)) {
      return;
    }

    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final initFuture = _initializeInternal();
    _initializeFuture = initFuture;
    try {
      await initFuture;
    } finally {
      if (identical(_initializeFuture, initFuture)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (_activeKeyVersion != null &&
        _keysByVersion.containsKey(_activeKeyVersion)) {
      return;
    }

    final storedActiveVersionRaw = await _storage.read(
      key: _activeVersionStorageName,
    );
    final storedActiveVersion = int.tryParse(storedActiveVersionRaw ?? '');
    _activeKeyVersion = storedActiveVersion ?? _defaultActiveKeyVersion;

    final legacyBase64 = await _storage.read(key: _legacyKeyStorageName);
    if (legacyBase64 != null && legacyBase64.trim().isNotEmpty) {
      _keysByVersion[1] = SecretKey(base64Decode(legacyBase64));
    }

    final activeVersion = _activeKeyVersion!;
    final activeKeyStorageName = _storageKeyName(activeVersion);
    var activeKeyBase64 = await _storage.read(key: activeKeyStorageName);

    if (activeKeyBase64 == null || activeKeyBase64.trim().isEmpty) {
      final keyBytes = _generateSecureBytes(32);
      activeKeyBase64 = base64Encode(keyBytes);
      await _storage.write(key: activeKeyStorageName, value: activeKeyBase64);
    }

    _keysByVersion[activeVersion] = SecretKey(base64Decode(activeKeyBase64));

    await _storage.write(
      key: _activeVersionStorageName,
      value: activeVersion.toString(),
    );

    final lastRotationAt = await _storage.read(key: _lastRotationAtStorageName);
    if (lastRotationAt == null || lastRotationAt.trim().isEmpty) {
      await _markRotationNow();
    }

    if (legacyBase64 != null && legacyBase64.trim().isNotEmpty) {
      final migratedKeyStorageName = _storageKeyName(1);
      final existingMigrated = await _storage.read(key: migratedKeyStorageName);
      if (existingMigrated == null || existingMigrated.trim().isEmpty) {
        await _storage.write(key: migratedKeyStorageName, value: legacyBase64);
      }
    }
  }

  Future<void> rotateActiveKey() async {
    await initialize();

    final nextVersion = (_activeKeyVersion ?? _defaultActiveKeyVersion) + 1;
    final keyBytes = _generateSecureBytes(32);
    final keyBase64 = base64Encode(keyBytes);

    await _storage.write(key: _storageKeyName(nextVersion), value: keyBase64);
    await _storage.write(
      key: _activeVersionStorageName,
      value: nextVersion.toString(),
    );

    _activeKeyVersion = nextVersion;
    _keysByVersion[nextVersion] = SecretKey(keyBytes);
    await _markRotationNow();
  }

  Future<int> getActiveKeyVersion() async {
    await initialize();
    return _activeKeyVersion ?? _defaultActiveKeyVersion;
  }

  Future<bool> shouldRotateKey() async {
    await initialize();

    final lastRotationRaw = await _storage.read(
      key: _lastRotationAtStorageName,
    );
    if (lastRotationRaw == null || lastRotationRaw.trim().isEmpty) {
      return true;
    }

    final lastRotationAt = DateTime.tryParse(lastRotationRaw);
    if (lastRotationAt == null) {
      return true;
    }

    final age = DateTime.now().difference(lastRotationAt);
    return age.inDays >= _rotationIntervalDays;
  }

  Future<String> encryptText(String plainText) async {
    await initialize();

    final activeVersion = _activeKeyVersion ?? _defaultActiveKeyVersion;
    final secretKey = _keysByVersion[activeVersion]!;
    final nonce = _generateSecureBytes(12);

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'v': activeVersion,
      'alg': _encryptionAlgorithmName,
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    return jsonEncode(envelope);
  }

  Future<String> decryptText(String encryptedEnvelope) async {
    await initialize();

    final trimmedEnvelope = encryptedEnvelope.trim();
    if (trimmedEnvelope.isEmpty) {
      throw const FormatException('Encrypted envelope is empty.');
    }

    final decodedJson = jsonDecode(trimmedEnvelope);
    if (decodedJson is! Map<String, dynamic>) {
      throw const FormatException('Encrypted envelope must be a JSON object.');
    }
    final map = decodedJson;

    final algorithmName = (map['alg'] ?? '').toString().trim();
    if (algorithmName.isNotEmpty && algorithmName != _encryptionAlgorithmName) {
      throw FormatException('Unsupported encryption algorithm: $algorithmName');
    }

    final versionRaw = map['v'];
    final version = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '') ?? 1;
    if (version <= 0) {
      throw FormatException('Invalid encryption key version: $version');
    }

    final secretKey = await _getSecretKeyForVersion(version);

    if (secretKey == null) {
      throw StateError('No local encryption key found for version $version');
    }

    final nonce = _decodeBase64Field(map, 'nonce');
    if (nonce.length != _expectedNonceLength) {
      throw const FormatException(
        'Invalid nonce length in encrypted envelope.',
      );
    }

    final cipherText = _decodeBase64Field(map, 'cipherText');
    final macBytes = _decodeBase64Field(map, 'mac');
    if (macBytes.length != _expectedMacLength) {
      throw const FormatException('Invalid MAC length in encrypted envelope.');
    }

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    final plainBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(plainBytes);
  }

  Future<SecretKey?> _getSecretKeyForVersion(int version) async {
    final cached = _keysByVersion[version];
    if (cached != null) {
      return cached;
    }

    final storedBase64 = await _storage.read(key: _storageKeyName(version));
    if (storedBase64 != null && storedBase64.trim().isNotEmpty) {
      final loaded = SecretKey(base64Decode(storedBase64));
      _keysByVersion[version] = loaded;
      return loaded;
    }

    if (version == 1) {
      final legacyBase64 = await _storage.read(key: _legacyKeyStorageName);
      if (legacyBase64 != null && legacyBase64.trim().isNotEmpty) {
        final legacy = SecretKey(base64Decode(legacyBase64));
        _keysByVersion[1] = legacy;
        return legacy;
      }
    }

    return null;
  }

  List<int> _decodeBase64Field(Map<String, dynamic> map, String fieldName) {
    final raw = (map[fieldName] ?? '').toString().trim();
    if (raw.isEmpty) {
      throw FormatException(
        'Missing field "$fieldName" in encrypted envelope.',
      );
    }
    return base64Decode(raw);
  }

  List<int> _generateSecureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _storageKeyName(int version) => '$_keyStoragePrefix$version';

  Future<void> _markRotationNow() async {
    await _storage.write(
      key: _lastRotationAtStorageName,
      value: DateTime.now().toIso8601String(),
    );
  }
}
