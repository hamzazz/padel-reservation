class Reservation {
  final String id;
  final String userId;
  final String courtId;
  final String courtName;
  final DateTime date;
  final String timeSlot;
  final String playerName;
  final int numberOfPlayers;
  final double totalPrice;
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.userId,
    required this.courtId,
    required this.courtName,
    required this.date,
    required this.timeSlot,
    required this.playerName,
    required this.numberOfPlayers,
    required this.totalPrice,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'courtId': courtId,
      'courtName': courtName,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
      'playerName': playerName,
      'numberOfPlayers': numberOfPlayers,
      'totalPrice': totalPrice,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      userId: map['userId'] ?? '',
      courtId: map['courtId'],
      courtName: map['courtName'],
      date: DateTime.parse(map['date']),
      timeSlot: map['timeSlot'],
      playerName: map['playerName'],
      numberOfPlayers: map['numberOfPlayers'],
      totalPrice: (map['totalPrice'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

const List<String> timeSlots = [
  '08:00 - 09:30',
  '09:30 - 11:00',
  '11:00 - 12:30',
  '14:00 - 15:30',
  '15:30 - 17:00',
  '17:00 - 18:30',
  '18:30 - 20:00',
  '20:00 - 21:30',
  '21:30 - 23:00',
];
