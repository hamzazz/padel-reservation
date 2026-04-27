import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/elo_match.dart';

class EloService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eloMatches =>
      _db.collection('elo_matches');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── ELO formula ───────────────────────────────────────────────────────────

  double _expected(int ratingA, int ratingB) =>
      1.0 / (1.0 + pow(10.0, (ratingB - ratingA) / 400.0));

  int _kFactor(int matchesPlayed) {
    if (matchesPlayed < 30) return 32;
    if (matchesPlayed < 100) return 24;
    return 16;
  }

  // ── Submit result ─────────────────────────────────────────────────────────

  Future<void> submitResult({
    required String submittedBy,
    required List<AppUser> team1,
    required List<AppUser> team2,
    required String winnerTeam,
    String courtName = '',
    DateTime? playedAt,
  }) async {
    final ref = _eloMatches.doc();
    final match = EloMatch(
      id: ref.id,
      team1Ids: team1.map((u) => u.id).toList(),
      team2Ids: team2.map((u) => u.id).toList(),
      team1Names: team1.map((u) => u.fullName).toList(),
      team2Names: team2.map((u) => u.fullName).toList(),
      winnerTeam: winnerTeam,
      submittedBy: submittedBy,
      confirmedBy: [submittedBy],
      status: 'pending',
      eloChanges: {},
      eloBefore: {},
      courtName: courtName,
      playedAt: playedAt ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
    await ref.set(match.toMap());
  }

  // ── Confirm result ────────────────────────────────────────────────────────

  Future<String> confirmResult(String eloMatchId, String userId) async {
    final doc = await _eloMatches.doc(eloMatchId).get();
    if (!doc.exists) return 'Match introuvable';

    final match = EloMatch.fromMap(doc.data()!);
    if (match.status != 'pending') return 'Résultat déjà traité';
    if (!match.allIds.contains(userId)) return 'Vous n\'êtes pas dans ce match';
    if (match.confirmedBy.contains(userId)) return 'Vous avez déjà confirmé';

    final newConfirmed = [...match.confirmedBy, userId];

    final team1Confirmed = newConfirmed.any((id) => match.team1Ids.contains(id));
    final team2Confirmed = newConfirmed.any((id) => match.team2Ids.contains(id));

    if (team1Confirmed && team2Confirmed) {
      await _applyElo(match, newConfirmed);
      return 'ok';
    } else {
      await _eloMatches.doc(eloMatchId).update({'confirmedBy': newConfirmed});
      return 'ok';
    }
  }

  // ── Dispute result ────────────────────────────────────────────────────────

  Future<void> disputeResult(String eloMatchId, String userId) async {
    await _eloMatches.doc(eloMatchId).update({
      'status': 'disputed',
      'disputedBy': userId,
    });
  }

  // ── Apply ELO changes ─────────────────────────────────────────────────────

  Future<void> _applyElo(EloMatch match, List<String> confirmedBy) async {
    final userDocs = await Future.wait(
      match.allIds.map((id) => _users.doc(id).get()),
    );

    final users = <String, AppUser>{};
    for (final doc in userDocs) {
      if (doc.exists) {
        users[doc.id] = AppUser.fromMap(_convertTs(doc.data()!));
      }
    }

    // Average ELO per team
    final t1Elo = match.team1Ids
            .map((id) => users[id]?.eloRating ?? 1000)
            .reduce((a, b) => a + b) /
        match.team1Ids.length;
    final t2Elo = match.team2Ids
            .map((id) => users[id]?.eloRating ?? 1000)
            .reduce((a, b) => a + b) /
        match.team2Ids.length;

    final eloChanges = <String, int>{};
    final eloBefore = <String, int>{};

    for (final id in match.team1Ids) {
      final user = users[id];
      if (user == null) continue;
      eloBefore[id] = user.eloRating;
      final exp = _expected(t1Elo.round(), t2Elo.round());
      final actual = match.winnerTeam == '1' ? 1.0 : 0.0;
      eloChanges[id] = (_kFactor(user.eloMatchesPlayed) * (actual - exp)).round();
    }

    for (final id in match.team2Ids) {
      final user = users[id];
      if (user == null) continue;
      eloBefore[id] = user.eloRating;
      final exp = _expected(t2Elo.round(), t1Elo.round());
      final actual = match.winnerTeam == '2' ? 1.0 : 0.0;
      eloChanges[id] = (_kFactor(user.eloMatchesPlayed) * (actual - exp)).round();
    }

    final batch = _db.batch();

    for (final id in match.allIds) {
      final user = users[id];
      if (user == null) continue;
      final delta = eloChanges[id] ?? 0;
      final isWinner =
          (match.winnerTeam == '1' && match.team1Ids.contains(id)) ||
              (match.winnerTeam == '2' && match.team2Ids.contains(id));
      batch.update(_users.doc(id), {
        'eloRating': (user.eloRating + delta).clamp(100, 3000),
        'eloMatchesPlayed': user.eloMatchesPlayed + 1,
        'eloWins': user.eloWins + (isWinner ? 1 : 0),
      });
    }

    batch.update(_eloMatches.doc(match.id), {
      'status': 'confirmed',
      'confirmedBy': confirmedBy,
      'eloChanges': eloChanges,
      'eloBefore': eloBefore,
    });

    await batch.commit();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<EloMatch>> getPendingForUser(String userId) async {
    final snap = await _eloMatches
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs
        .map((d) => EloMatch.fromMap(d.data()))
        .where((m) =>
            m.allIds.contains(userId) && !m.confirmedBy.contains(userId))
        .toList();
  }

  Future<List<EloMatch>> getRecentForUser(String userId,
      {int limit = 8}) async {
    try {
      // No orderBy to avoid composite index requirement — sort client-side
      final snap = await _eloMatches
          .where('status', isEqualTo: 'confirmed')
          .get();
      final list = snap.docs
          .map((d) => EloMatch.fromMap(d.data()))
          .where((m) => m.allIds.contains(userId))
          .toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AppUser>> getLeaderboard({int limit = 50}) async {
    final snap = await _users.get();
    final all = snap.docs
        .map((d) => AppUser.fromMap(_convertTs(d.data())))
        .toList();
    all.sort((a, b) => b.eloRating.compareTo(a.eloRating));
    return all.take(limit).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _convertTs(Map<String, dynamic> map) =>
      map.map((k, v) {
        if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
        if (v is Map<String, dynamic>) return MapEntry(k, _convertTs(v));
        return MapEntry(k, v);
      });
}
