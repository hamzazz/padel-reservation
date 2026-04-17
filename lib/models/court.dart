class Court {
  final String id;
  final String name;
  final String description;
  final double pricePerHour;
  final bool isIndoor;
  final String address;
  final double latitude;
  final double longitude;

  const Court({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerHour,
    required this.isIndoor,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
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
