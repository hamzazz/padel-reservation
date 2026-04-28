import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import 'whatsapp_service.dart';

class NotificationService {
  final _col = FirebaseFirestore.instance.collection('notifications');

  Future<List<AppNotification>> getForUser(String userId) async {
    try {
      final snap = await _col.where('userId', isEqualTo: userId).get();
      final list = snap.docs.map((d) => AppNotification.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<int> unreadCount(String userId) async {
    try {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> push({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? phone, // if provided → also send WhatsApp
  }) async {
    final id = const Uuid().v4();
    // In-app notification
    await _col.doc(id).set({
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    // WhatsApp notification (fire-and-forget)
    if (phone != null && phone.isNotEmpty) {
      final waMsg = '🎾 *Padel Club*\n\n*$title*\n\n$body';
      WhatsAppService.send(phone, waMsg);
    }
  }

  Future<void> markAllRead(String userId) async {
    try {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
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
