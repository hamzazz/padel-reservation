import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation.dart';

class ReservationService {
  final _col = FirebaseFirestore.instance.collection('reservations');

  Future<List<Reservation>> getAll() async {
    final snap = await _col.orderBy('date').get();
    return snap.docs.map((d) => Reservation.fromMap(_ts(d.data()))).toList();
  }

  Future<List<Reservation>> getForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('date')
        .get();
    return snap.docs.map((d) => Reservation.fromMap(_ts(d.data()))).toList();
  }

  Future<void> save(Reservation reservation) async {
    await _col.doc(reservation.id).set(_toFirestore(reservation.toMap()));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<bool> isSlotTaken(
      String courtId, DateTime date, String timeSlot) async {
    final snap = await _col
        .where('courtId', isEqualTo: courtId)
        .where('timeSlot', isEqualTo: timeSlot)
        .get();
    return snap.docs.any((d) {
      final data = d.data();
      final storedDate = data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.parse(data['date'] as String);
      return storedDate.year == date.year &&
          storedDate.month == date.month &&
          storedDate.day == date.day;
    });
  }

  Map<String, dynamic> _toFirestore(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null && (k == 'date' || k == 'createdAt')) {
          return MapEntry(k, Timestamp.fromDate(dt));
        }
      }
      return MapEntry(k, v);
    });
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
