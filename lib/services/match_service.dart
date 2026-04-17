import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class MatchService {
  final _col = FirebaseFirestore.instance.collection('matches');

  Future<List<Match>> getAll() async {
    final snap = await _col.orderBy('date').get();
    return snap.docs.map((d) => Match.fromMap(_ts(d.data()))).toList();
  }

  Future<Match?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Match.fromMap(_ts(doc.data()!));
  }

  Future<void> save(Match match) async {
    await _col.doc(match.id).set(_toFirestore(match.toMap()));
  }

  Future<void> update(Match match) async {
    await _col.doc(match.id).set(_toFirestore(match.toMap()));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<bool> joinMatch(String matchId, MatchPlayer player) async {
    final match = await getById(matchId);
    if (match == null || match.isFull) return false;
    if (match.players.any((p) => p.id == player.id)) return false;
    final updated = match.copyWith(
      players: [...match.players, player],
      status: match.players.length + 1 >= match.maxPlayers ? 'full' : 'open',
    );
    await update(updated);
    return true;
  }

  Future<bool> payForMatch(String matchId, String playerId) async {
    final match = await getById(matchId);
    if (match == null) return false;
    final updatedPlayers = match.players.map((p) {
      if (p.id == playerId) return p.copyWith(hasPaid: true);
      return p;
    }).toList();
    await update(match.copyWith(players: updatedPlayers));
    return true;
  }

  Map<String, dynamic> _toFirestore(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is String && (k == 'date' || k == 'createdAt')) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return MapEntry(k, Timestamp.fromDate(dt));
      }
      if (v is List && k == 'players') {
        return MapEntry(k, (v as List).map((p) {
          if (p is Map<String, dynamic>) {
            return p.map((pk, pv) {
              if (pv is String && pk == 'joinedAt') {
                final dt = DateTime.tryParse(pv);
                if (dt != null) return MapEntry(pk, Timestamp.fromDate(dt));
              }
              return MapEntry(pk, pv);
            });
          }
          return p;
        }).toList());
      }
      return MapEntry(k, v);
    });
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      if (v is List && k == 'players') {
        return MapEntry(k, (v as List).map((p) {
          if (p is Map<String, dynamic>) {
            return p.map((pk, pv) {
              if (pv is Timestamp) return MapEntry(pk, pv.toDate().toIso8601String());
              return MapEntry(pk, pv);
            });
          }
          return p;
        }).toList());
      }
      return MapEntry(k, v);
    });
  }
}
