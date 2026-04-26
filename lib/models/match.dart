class MatchPlayer {
  final String id;
  final String name;
  final bool hasPaid;
  final DateTime joinedAt;

  MatchPlayer({
    required this.id,
    required this.name,
    required this.hasPaid,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hasPaid': hasPaid,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory MatchPlayer.fromMap(Map<String, dynamic> map) => MatchPlayer(
        id: map['id'],
        name: map['name'],
        hasPaid: map['hasPaid'] ?? false,
        joinedAt: DateTime.parse(map['joinedAt']),
      );

  MatchPlayer copyWith({bool? hasPaid}) => MatchPlayer(
        id: id,
        name: name,
        hasPaid: hasPaid ?? this.hasPaid,
        joinedAt: joinedAt,
      );
}

const List<String> levelLabels = [
  '', 'Débutant', 'Novice', 'Intermédiaire−', 'Intermédiaire',
  'Intermédiaire+', 'Avancé', 'Expert', 'Pro',
];

class Match {
  final String id;
  final String organizerId;
  final String courtId;
  final String courtName;
  final DateTime date;
  final String timeSlot;
  final String organizerName;
  final int maxPlayers;
  final List<MatchPlayer> players;
  final double pricePerPlayer;
  final String status;
  final DateTime createdAt;
  final int level;

  Match({
    required this.id,
    this.organizerId = '',
    required this.courtId,
    required this.courtName,
    required this.date,
    required this.timeSlot,
    required this.organizerName,
    required this.maxPlayers,
    required this.players,
    required this.pricePerPlayer,
    required this.status,
    required this.createdAt,
    this.level = 0,
  });

  bool get isFull => players.length >= maxPlayers;
  int get availableSpots => maxPlayers - players.length;
  String get levelLabel => level > 0 && level <= 8 ? levelLabels[level] : 'Tous niveaux';

  Match copyWith({List<MatchPlayer>? players, String? status}) => Match(
        id: id,
        organizerId: organizerId,
        courtId: courtId,
        courtName: courtName,
        date: date,
        timeSlot: timeSlot,
        organizerName: organizerName,
        maxPlayers: maxPlayers,
        players: players ?? this.players,
        pricePerPlayer: pricePerPlayer,
        status: status ?? this.status,
        createdAt: createdAt,
        level: level,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizerId': organizerId,
        'courtId': courtId,
        'courtName': courtName,
        'date': date.toIso8601String(),
        'timeSlot': timeSlot,
        'organizerName': organizerName,
        'maxPlayers': maxPlayers,
        'players': players.map((p) => p.toMap()).toList(),
        'pricePerPlayer': pricePerPlayer,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'level': level,
      };

  factory Match.fromMap(Map<String, dynamic> map) => Match(
        id: map['id'],
        organizerId: map['organizerId'] ?? '',
        courtId: map['courtId'],
        courtName: map['courtName'],
        date: DateTime.parse(map['date']),
        timeSlot: map['timeSlot'],
        organizerName: map['organizerName'],
        maxPlayers: map['maxPlayers'],
        players: (map['players'] as List)
            .map((p) => MatchPlayer.fromMap(p as Map<String, dynamic>))
            .toList(),
        pricePerPlayer: (map['pricePerPlayer'] as num).toDouble(),
        status: map['status'],
        createdAt: DateTime.parse(map['createdAt']),
        level: (map['level'] as int?) ?? 0,
      );
}
