import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  String _locale = 'fr';

  String get locale => _locale;
  bool get isRtl => _locale == 'ar';
  Locale get flutterLocale => Locale(_locale);

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString('locale') ?? 'fr';
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    if (!['fr', 'en', 'ar'].contains(locale)) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    notifyListeners();
  }

  String tr(String key) {
    return appStrings[_locale]?[key] ?? appStrings['fr']?[key] ?? key;
  }
}
