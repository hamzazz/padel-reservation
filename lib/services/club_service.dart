import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/club.dart';
import '../models/reservation.dart';
import '../models/match.dart';
import '../models/tournament.dart';

class ClubService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection('clubs');

  Future<List<Club>> getAll() async {
    try {
      final snap = await _clubs.get();
      return snap.docs.map((d) => Club.fromMap(_ts(d.data()))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Club?> getById(String id) async {
    try {
      final doc = await _clubs.doc(id).get();
      if (!doc.exists) return null;
      return Club.fromMap(_ts(doc.data()!));
    } catch (_) {
      return null;
    }
  }

  Future<Club> create({
    required String name,
    required String address,
  }) async {
    final club = Club(
      id: const Uuid().v4(),
      name: name,
      address: address,
      courtIds: [],
      adminIds: [],
      createdAt: DateTime.now(),
    );
    await _clubs.doc(club.id).set(club.toMap());
    return club;
  }

  Future<void> update(Club club) async {
    await _clubs.doc(club.id).set(club.toMap());
  }

  Future<void> delete(String clubId) async {
    await _clubs.doc(clubId).delete();
  }

  // ── Données filtrées par club ─────────────────────────────────────────

  Future<List<Reservation>> getReservations(List<String> courtIds) async {
    if (courtIds.isEmpty) return [];
    try {
      final snap = await _db
          .collection('reservations')
          .where('courtId', whereIn: courtIds)
          .get();
      final list = snap.docs.map((d) => Reservation.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Match>> getMatches(List<String> courtIds) async {
    if (courtIds.isEmpty) return [];
    try {
      final snap = await _db
          .collection('matches')
          .where('courtId', whereIn: courtIds)
          .get();
      final list = snap.docs.map((d) => Match.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Tournament>> getTournaments(List<String> courtIds) async {
    if (courtIds.isEmpty) return [];
    try {
      final snap = await _db
          .collection('tournaments')
          .where('courtId', whereIn: courtIds)
          .get();
      final list = snap.docs.map((d) => Tournament.fromMap(_ts(d.data()))).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  // ── Assign admin ──────────────────────────────────────────────────────

  Future<void> addAdmin(String clubId, String userId) async {
    await _clubs.doc(clubId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
    });
    await _db.collection('users').doc(userId).update({
      'isClubAdmin': true,
      'clubId': clubId,
    });
  }

  Future<void> removeAdmin(String clubId, String userId) async {
    await _clubs.doc(clubId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
    });
    await _db.collection('users').doc(userId).update({
      'isClubAdmin': false,
      'clubId': '',
    });
  }

  // ── Assign courts ────────────────────────────────────────────────────

  Future<void> setCourtIds(String clubId, List<String> courtIds) async {
    await _clubs.doc(clubId).update({'courtIds': courtIds});
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
