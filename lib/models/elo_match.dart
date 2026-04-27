class EloMatch {
  final String id;
  final List<String> team1Ids;
  final List<String> team2Ids;
  final List<String> team1Names;
  final List<String> team2Names;
  final String winnerTeam; // '1' | '2'
  final String submittedBy;
  final List<String> confirmedBy;
  final String status; // 'pending' | 'confirmed' | 'disputed'
  final Map<String, int> eloChanges; // playerId → delta
  final Map<String, int> eloBefore;  // playerId → elo before
  final String courtName;
  final DateTime playedAt;
  final DateTime createdAt;

  EloMatch({
    required this.id,
    required this.team1Ids,
    required this.team2Ids,
    required this.team1Names,
    required this.team2Names,
    required this.winnerTeam,
    required this.submittedBy,
    required this.confirmedBy,
    required this.status,
    required this.eloChanges,
    required this.eloBefore,
    required this.courtName,
    required this.playedAt,
    required this.createdAt,
  });

  List<String> get allIds => [...team1Ids, ...team2Ids];

  Map<String, dynamic> toMap() => {
        'id': id,
        'team1Ids': team1Ids,
        'team2Ids': team2Ids,
        'team1Names': team1Names,
        'team2Names': team2Names,
        'winnerTeam': winnerTeam,
        'submittedBy': submittedBy,
        'confirmedBy': confirmedBy,
        'status': status,
        'eloChanges': eloChanges.map((k, v) => MapEntry(k, v)),
        'eloBefore': eloBefore.map((k, v) => MapEntry(k, v)),
        'courtName': courtName,
        'playedAt': playedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory EloMatch.fromMap(Map<String, dynamic> m) => EloMatch(
        id: m['id'],
        team1Ids: List<String>.from(m['team1Ids'] ?? []),
        team2Ids: List<String>.from(m['team2Ids'] ?? []),
        team1Names: List<String>.from(m['team1Names'] ?? []),
        team2Names: List<String>.from(m['team2Names'] ?? []),
        winnerTeam: m['winnerTeam'] ?? '1',
        submittedBy: m['submittedBy'] ?? '',
        confirmedBy: List<String>.from(m['confirmedBy'] ?? []),
        status: m['status'] ?? 'pending',
        eloChanges: (m['eloChanges'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        eloBefore: (m['eloBefore'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        courtName: m['courtName'] ?? '',
        playedAt: DateTime.parse(m['playedAt']),
        createdAt: DateTime.parse(m['createdAt']),
      );
}

// ── ELO tier helpers ─────────────────────────────────────────────────────────

enum EloTier { bronze, silver, gold, platinum, diamond }

EloTier eloTierOf(int elo) {
  if (elo < 1200) return EloTier.bronze;
  if (elo < 1400) return EloTier.silver;
  if (elo < 1600) return EloTier.gold;
  if (elo < 1800) return EloTier.platinum;
  return EloTier.diamond;
}

String eloTierName(int elo) {
  switch (eloTierOf(elo)) {
    case EloTier.bronze:   return 'Bronze';
    case EloTier.silver:   return 'Argent';
    case EloTier.gold:     return 'Or';
    case EloTier.platinum: return 'Platine';
    case EloTier.diamond:  return 'Diamant';
  }
}

String eloTierEmoji(int elo) {
  switch (eloTierOf(elo)) {
    case EloTier.bronze:   return '🥉';
    case EloTier.silver:   return '🥈';
    case EloTier.gold:     return '🥇';
    case EloTier.platinum: return '💎';
    case EloTier.diamond:  return '👑';
  }
}

int eloTierColorValue(int elo) {
  switch (eloTierOf(elo)) {
    case EloTier.bronze:   return 0xFFCD7F32;
    case EloTier.silver:   return 0xFF8E8E8E;
    case EloTier.gold:     return 0xFFFFB800;
    case EloTier.platinum: return 0xFF00BCD4;
    case EloTier.diamond:  return 0xFF9C27B0;
  }
}

// Next tier threshold
int eloNextTierThreshold(int elo) {
  if (elo < 1200) return 1200;
  if (elo < 1400) return 1400;
  if (elo < 1600) return 1600;
  if (elo < 1800) return 1800;
  return 9999;
}
