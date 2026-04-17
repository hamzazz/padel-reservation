class Tournament {
  final String id;
  final String organizerId;
  final String organizerName;
  final String name;
  final String description;
  final DateTime date;
  final String courtId;
  final String courtName;
  final int maxParticipants;
  final List<String> participantIds;
  final List<String> participantNames;
  final double entryFee;
  String status; // 'open' | 'full' | 'ongoing' | 'completed' | 'cancelled'
  final String format; // 'single' | 'double'
  final DateTime createdAt;

  Tournament({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    required this.name,
    required this.description,
    required this.date,
    required this.courtId,
    required this.courtName,
    required this.maxParticipants,
    required this.participantIds,
    required this.participantNames,
    required this.entryFee,
    required this.status,
    required this.format,
    required this.createdAt,
  });

  bool get isFull => participantIds.length >= maxParticipants;
  int get spotsLeft => maxParticipants - participantIds.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizerId': organizerId,
        'organizerName': organizerName,
        'name': name,
        'description': description,
        'date': date.toIso8601String(),
        'courtId': courtId,
        'courtName': courtName,
        'maxParticipants': maxParticipants,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'entryFee': entryFee,
        'status': status,
        'format': format,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Tournament.fromMap(Map<String, dynamic> m) => Tournament(
        id: m['id'],
        organizerId: m['organizerId'],
        organizerName: m['organizerName'],
        name: m['name'],
        description: m['description'],
        date: DateTime.parse(m['date']),
        courtId: m['courtId'],
        courtName: m['courtName'],
        maxParticipants: m['maxParticipants'],
        participantIds: List<String>.from(m['participantIds'] ?? []),
        participantNames: List<String>.from(m['participantNames'] ?? []),
        entryFee: (m['entryFee'] as num).toDouble(),
        status: m['status'],
        format: m['format'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}
