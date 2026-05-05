import 'dart:io';
import 'package:flutter/material.dart';
import '../models/court.dart';
import '../services/court_service.dart';

class CourtProvider extends ChangeNotifier {
  final _svc = CourtService();
  List<Court> _courts = [];
  bool _loading = true;

  List<Court> get courts => _courts;
  List<Court> get activeCourts => _courts.where((c) => c.isActive).toList();
  bool get loading => _loading;

  Future<void> init() async {
    await _svc.seedIfEmpty(availableCourts);
    await _svc.seedRabat();
    await _svc.seedCasablancaMarrakech();
    await refresh();
  }

  Future<void> refresh() async {
    final list = await _svc.getAll();
    _courts = list.isNotEmpty ? list : List.from(availableCourts);
    _loading = false;
    notifyListeners();
  }

  Future<Court> addCourt({
    required String name,
    required String description,
    required double pricePerHour,
    required bool isIndoor,
    required String address,
    required double latitude,
    required double longitude,
    int maxReservationsPerSlot = 1,
    String city = '',
    File? imageFile,
  }) async {
    Court? court;
    try {
      court = await _svc.add(
        name: name,
        description: description,
        pricePerHour: pricePerHour,
        isIndoor: isIndoor,
        address: address,
        latitude: latitude,
        longitude: longitude,
        maxReservationsPerSlot: maxReservationsPerSlot,
        city: city,
        imageFile: imageFile,
      );
      _courts.add(court);
      notifyListeners();
      return court;
    } catch (e) {
      // Court was saved but image upload failed — update list then rethrow
      if (court == null) rethrow;
      _courts.add(court);
      notifyListeners();
      rethrow;
    }
  }

  Future<Court> updateCourt(Court court, {File? imageFile}) async {
    Court? updated;
    try {
      updated = await _svc.update(court, imageFile: imageFile);
      final idx = _courts.indexWhere((c) => c.id == court.id);
      if (idx != -1) _courts[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      // Court was saved but image upload failed — update list then rethrow
      if (updated == null) rethrow;
      final idx = _courts.indexWhere((c) => c.id == court.id);
      if (idx != -1) _courts[idx] = updated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleActive(String courtId, bool isActive) async {
    await _svc.toggleActive(courtId, isActive);
    final idx = _courts.indexWhere((c) => c.id == courtId);
    if (idx != -1) {
      _courts[idx] = _courts[idx].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  Future<void> deleteCourt(String courtId) async {
    await _svc.delete(courtId);
    _courts.removeWhere((c) => c.id == courtId);
    notifyListeners();
  }

  Court? findById(String id) {
    try {
      return _courts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
