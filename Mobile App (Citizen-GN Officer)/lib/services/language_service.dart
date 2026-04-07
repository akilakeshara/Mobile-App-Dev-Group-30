import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class LanguageService extends ChangeNotifier {
  static const String _languagePrefKey = 'preferred_language_code';
  static const Set<String> _supportedCodes = {'en', 'si', 'ta'};

  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  String get currentLanguageCode => _locale.languageCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languagePrefKey);
    if (saved != null && _supportedCodes.contains(saved)) {
      _locale = Locale(saved);
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      final user = await firestoreService.getUser(authUser.uid);
      final remote = user?.preferredLanguage;
      if (remote != null &&
          _supportedCodes.contains(remote) &&
          remote != _locale.languageCode) {
        _locale = Locale(remote);
        await prefs.setString(_languagePrefKey, remote);
      }
    }

    notifyListeners();
  }

  Future<void> setLanguage(
    String languageCode, {
    bool syncRemote = true,
  }) async {
    if (!_supportedCodes.contains(languageCode)) return;

    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, languageCode);

    if (!syncRemote) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await firestoreService.updateUserPreferredLanguage(
        user.uid,
        languageCode,
      );
    }
  }
}

final languageService = LanguageService();
