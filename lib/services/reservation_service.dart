import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation.dart';

class ReservationService {
  final _col = FirebaseFirestore.instance.collection('reservations');

  Future<List<Reservation>> getAll() async {
    try {
      final snap = await _col.get();
      final list = snap.docs.map((d) => Reservation.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<Reservation>> getForUser(String userId) async {
    try {
      final snap = await _col.where('userId', isEqualTo: userId).get();
      final list = snap.docs.map((d) => Reservation.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> save(Reservation reservation) async {
    await _col.doc(reservation.id).set({
      ...reservation.toMap(),
      'date': Timestamp.fromDate(reservation.date),
      'createdAt': Timestamp.fromDate(reservation.createdAt),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<int> countSlotReservations(String courtId, DateTime date, String timeSlot) async {
    try {
      final snap = await _col
          .where('courtId', isEqualTo: courtId)
          .where('timeSlot', isEqualTo: timeSlot)
          .get();
      return snap.docs.where((d) {
        final data = d.data();
        final storedDate = data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.parse(data['date'] as String);
        return storedDate.year == date.year &&
            storedDate.month == date.month &&
            storedDate.day == date.day;
      }).length;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> isSlotTaken(String courtId, DateTime date, String timeSlot,
      {int maxReservations = 1}) async {
    final count = await countSlotReservations(courtId, date, timeSlot);
    return count >= maxReservations;
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
