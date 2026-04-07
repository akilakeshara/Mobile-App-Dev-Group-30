import 'package:translator/translator.dart';
import '../services/language_service.dart';
import 'logger.dart';

class TranslationUtil {
  static final _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};

  /// Translates text on the fly to the user's preferred language.
  /// Used for translating dynamic database text (e.g. Officer Remarks, Notification bodies)
  static Future<String> translateForUser(String sourceText) async {
    if (sourceText.isEmpty) return sourceText;
    
    final targetLang = languageService.currentLanguageCode;
    // Assume source is English defaults from officers/sys
    if (targetLang == 'en') return sourceText; 
    
    final cacheKey = '${sourceText}_$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    try {
      final translation = await _translator.translate(sourceText, from: 'en', to: targetLang == 'si' ? 'si' : 'ta');
      _cache[cacheKey] = translation.text;
      return translation.text;
    } catch (e) {
      appLogger.e('Auto translation failed - Check network', error: e);
      return sourceText; // fallback to original
    }
  }
}
