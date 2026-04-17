import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/player_review.dart';

class ReviewService {
  final _col = FirebaseFirestore.instance.collection('reviews');

  Future<List<PlayerReview>> getForPlayer(String targetId) async {
    final snap = await _col
        .where('targetId', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PlayerReview.fromMap(_ts(d.data()))).toList();
  }

  Future<double> averageRating(String targetId) async {
    final list = await getForPlayer(targetId);
    if (list.isEmpty) return 0;
    return list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
  }

  Future<bool> hasReviewed(String reviewerId, String targetId) async {
    final snap = await _col
        .where('reviewerId', isEqualTo: reviewerId)
        .where('targetId', isEqualTo: targetId)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<String> submitReview({
    required String reviewerId,
    required String reviewerName,
    required String reviewerEmoji,
    required String targetId,
    required double rating,
    required String comment,
  }) async {
    // Replace existing review by same reviewer
    final existing = await _col
        .where('reviewerId', isEqualTo: reviewerId)
        .where('targetId', isEqualTo: targetId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    final id = const Uuid().v4();
    final now = DateTime.now();
    batch.set(_col.doc(id), {
      'id': id,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerEmoji': reviewerEmoji,
      'targetId': targetId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(now),
    });
    await batch.commit();
    return id;
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
