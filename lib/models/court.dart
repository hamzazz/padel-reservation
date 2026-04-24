class Court {
  final String id;
  final String name;
  final String description;
  final double pricePerHour;
  final bool isIndoor;
  final String address;
  final double latitude;
  final double longitude;
  final int maxReservationsPerSlot;

  const Court({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerHour,
    required this.isIndoor,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.maxReservationsPerSlot = 1,
  });

  Court copyWith({
    String? name,
    String? description,
    double? pricePerHour,
    bool? isIndoor,
    String? address,
    double? latitude,
    double? longitude,
    int? maxReservationsPerSlot,
  }) =>
      Court(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        isIndoor: isIndoor ?? this.isIndoor,
        address: address ?? this.address,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        maxReservationsPerSlot: maxReservationsPerSlot ?? this.maxReservationsPerSlot,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'pricePerHour': pricePerHour,
        'isIndoor': isIndoor,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'maxReservationsPerSlot': maxReservationsPerSlot,
      };

  factory Court.fromMap(Map<String, dynamic> m) => Court(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        pricePerHour: (m['pricePerHour'] as num).toDouble(),
        isIndoor: m['isIndoor'] as bool? ?? false,
        address: m['address'] as String? ?? '',
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        maxReservationsPerSlot: (m['maxReservationsPerSlot'] as int?) ?? 1,
      );
}

final List<Court> availableCourts = [
  const Court(
    id: 'c1',
    name: 'Terrain A',
    description: 'Terrain couvert avec éclairage LED',
    pricePerHour: 25.0,
    isIndoor: true,
    address: '12 Rue du Sport, Casablanca',
    latitude: 33.5731,
    longitude: -7.5898,
  ),
  const Court(
    id: 'c2',
    name: 'Terrain B',
    description: 'Terrain extérieur panoramique',
    pricePerHour: 18.0,
    isIndoor: false,
    address: '8 Avenue Mohammed V, Rabat',
    latitude: 34.0209,
    longitude: -6.8416,
  ),
  const Court(
    id: 'c3',
    name: 'Terrain C',
    description: 'Terrain VIP avec vestiaires privatifs',
    pricePerHour: 35.0,
    isIndoor: true,
    address: '25 Boulevard Anfa, Casablanca',
    latitude: 33.5892,
    longitude: -7.6336,
  ),
  const Court(
    id: 'c4',
    name: 'Terrain D',
    description: 'Terrain extérieur standard',
    pricePerHour: 15.0,
    isIndoor: false,
    address: '3 Rue Atlas, Marrakech',
    latitude: 31.6295,
    longitude: -7.9811,
  ),
];
