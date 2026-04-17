import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/tournament.dart';

class TournamentService {
  final _col = FirebaseFirestore.instance.collection('tournaments');

  Future<List<Tournament>> getAll() async {
    final snap = await _col.orderBy('date').get();
    return snap.docs.map((d) => Tournament.fromMap(_ts(d.data()))).toList();
  }

  Future<Tournament?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Tournament.fromMap(_ts(doc.data()!));
  }

  Future<Tournament> create({
    required String organizerId,
    required String organizerName,
    required String name,
    required String description,
    required DateTime date,
    required String courtId,
    required String courtName,
    required int maxParticipants,
    required double entryFee,
    required String format,
  }) async {
    final id = const Uuid().v4();
    final t = Tournament(
      id: id,
      organizerId: organizerId,
      organizerName: organizerName,
      name: name,
      description: description,
      date: date,
      courtId: courtId,
      courtName: courtName,
      maxParticipants: maxParticipants,
      participantIds: [],
      participantNames: [],
      entryFee: entryFee,
      status: 'open',
      format: format,
      createdAt: DateTime.now(),
    );
    final map = t.toMap();
    await _col.doc(id).set({
      ...map,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(t.createdAt),
    });
    return t;
  }

  Future<bool> join(
      String tournamentId, String userId, String userName) async {
    final doc = await _col.doc(tournamentId).get();
    if (!doc.exists) return false;
    final t = Tournament.fromMap(_ts(doc.data()!));
    if (t.isFull || t.participantIds.contains(userId)) return false;
    final newIds = [...t.participantIds, userId];
    final newNames = [...t.participantNames, userName];
    final newStatus = newIds.length >= t.maxParticipants ? 'full' : t.status;
    await _col.doc(tournamentId).update({
      'participantIds': newIds,
      'participantNames': newNames,
      'status': newStatus,
    });
    return true;
  }

  Future<void> updateStatus(String id, String status) async {
    await _col.doc(id).update({'status': status});
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
