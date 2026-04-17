import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';

class NotificationService {
  final _col = FirebaseFirestore.instance.collection('notifications');

  Future<List<AppNotification>> getForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => AppNotification.fromMap(_ts(d.data()))).toList();
  }

  Future<int> unreadCount(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snap.docs.length;
  }

  Future<void> push({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    final id = const Uuid().v4();
    await _col.doc(id).set({
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
