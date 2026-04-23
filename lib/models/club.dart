class Club {
  final String id;
  final String name;
  final String address;
  final List<String> courtIds;
  final List<String> adminIds;
  final DateTime createdAt;

  Club({
    required this.id,
    required this.name,
    required this.address,
    required this.courtIds,
    required this.adminIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'courtIds': courtIds,
        'adminIds': adminIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Club.fromMap(Map<String, dynamic> m) => Club(
        id: m['id'] as String,
        name: m['name'] as String,
        address: m['address'] as String? ?? '',
        courtIds: List<String>.from(m['courtIds'] ?? []),
        adminIds: List<String>.from(m['adminIds'] ?? []),
        createdAt: m['createdAt'] is String
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
      );

  Club copyWith({
    String? name,
    String? address,
    List<String>? courtIds,
    List<String>? adminIds,
  }) =>
      Club(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        courtIds: courtIds ?? this.courtIds,
        adminIds: adminIds ?? this.adminIds,
        createdAt: createdAt,
      );
}
