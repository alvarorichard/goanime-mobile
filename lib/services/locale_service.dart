import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale _locale = const Locale('en', 'US'); // English as default

  Locale get locale => _locale;

  LocaleService() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey);
    
    if (languageCode != null) {
      if (languageCode == 'pt') {
        _locale = const Locale('pt', 'BR');
      } else {
        _locale = const Locale('en', 'US');
      }
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> setEnglish() async {
    await setLocale(const Locale('en', 'US'));
  }

  Future<void> setPortuguese() async {
    await setLocale(const Locale('pt', 'BR'));
  }

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isPortuguese => _locale.languageCode == 'pt';
}
