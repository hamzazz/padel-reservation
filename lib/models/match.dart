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

class Match {
  final String id;
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

  Match({
    required this.id,
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
  });

  bool get isFull => players.length >= maxPlayers;
  int get availableSpots => maxPlayers - players.length;

  Match copyWith({List<MatchPlayer>? players, String? status}) => Match(
        id: id,
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
      );

  Map<String, dynamic> toMap() => {
        'id': id,
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
      };

  factory Match.fromMap(Map<String, dynamic> map) => Match(
        id: map['id'],
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
      );
}
