import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/court.dart';

class CityProvider extends ChangeNotifier {
  static const _key = 'selected_city';

  String _city = moroccanCities.first;
  String get selectedCity => _city;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && moroccanCities.contains(saved)) {
      _city = saved;
    }
    notifyListeners();
  }

  Future<void> selectCity(String city) async {
    if (_city == city) return;
    _city = city;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, city);
  }
}
