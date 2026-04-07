import CryptoJS from 'crypto-js';

const KEY = CryptoJS.enc.Utf8.parse('govease_secret_key_1234567890123'); // 32 chars
const IV = CryptoJS.enc.Utf8.parse('govease_iv_12345'); // 16 chars

/**
 * Decrypts text encrypted by the Flutter app using AES-256 CTR (SIC) mode.
 * Matches Flutter EncryptionUtil.dart logic.
 */
export const decryptText = (cipherText) => {
  if (!cipherText || typeof cipherText !== 'string') return cipherText || '';
  if (!cipherText.startsWith('ENC:')) return cipherText;

  try {
    const base64Data = cipherText.substring(4);
    const decrypted = CryptoJS.AES.decrypt(base64Data, KEY, {
      iv: IV,
      mode: CryptoJS.mode.CTR, // SIC is equivalent to CTR
      padding: CryptoJS.pad.NoPadding
    });
    const result = decrypted.toString(CryptoJS.enc.Utf8);
    return result || cipherText; // Return original if decryption results in empty (incorrect key/iv)
  } catch (e) {
    console.error('Decryption failed for:', cipherText.substring(0, 10) + '...', e);
    return cipherText;
  }
};
