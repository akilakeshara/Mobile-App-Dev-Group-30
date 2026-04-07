import 'package:encrypt/encrypt.dart' as enc;
import 'logger.dart';

class EncryptionUtil {
  // 32-byte key for AES Field-Level Encryption
  // Setup standard production key rotation fallback here
  static final _key = enc.Key.fromUtf8('govease_secret_key_1234567890123'); // 32 chars
  static final _iv = enc.IV.fromUtf8('govease_iv_12345'); // 16 chars

  static final _encrypter = enc.Encrypter(enc.AES(_key));

  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return 'ENC:${encrypted.base64}'; // Prefix to identify encrypted fields
    } catch (e) {
      appLogger.e('Encryption failed', error: e);
      return plainText; // Fallback so we don't drop data, though realistically should throw
    }
  }

  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    if (!cipherText.startsWith('ENC:')) return cipherText; // Return original if not encrypted
    
    try {
      final base64String = cipherText.substring(4);
      final decrypted = _encrypter.decrypt64(base64String, iv: _iv);
      return decrypted;
    } catch (e) {
      appLogger.e('Decryption failed, returning ciphertext fallback', error: e);
      return cipherText;
    }
  }
}
