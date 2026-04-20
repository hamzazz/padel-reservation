import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';

class CourtService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _courts =>
      _db.collection('courts');

  Future<List<Court>> getAll() async {
    try {
      final snap = await _courts.orderBy('name').get();
      return snap.docs.map((d) => Court.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(Court court) async {
    await _courts.doc(court.id).set(court.toMap());
  }

  Future<Court> add({
    required String name,
    required String description,
    required double pricePerHour,
    required bool isIndoor,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final court = Court(
      id: const Uuid().v4(),
      name: name,
      description: description,
      pricePerHour: pricePerHour,
      isIndoor: isIndoor,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    await _courts.doc(court.id).set(court.toMap());
    return court;
  }

  Future<void> update(Court court) async {
    await _courts.doc(court.id).set(court.toMap());
  }

  Future<void> delete(String courtId) async {
    await _courts.doc(courtId).delete();
  }

  Future<void> seedIfEmpty(List<Court> defaults) async {
    final snap = await _courts.limit(1).get();
    if (snap.docs.isEmpty) {
      for (final c in defaults) {
        await _courts.doc(c.id).set(c.toMap());
      }
    }
  }
}
