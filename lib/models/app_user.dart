class AppUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final int level; // 1-8
  final double walletBalance;
  final String avatarEmoji;
  final bool isAdmin;
  final List<String> friendIds;
  final List<String> blockedIds;
  final DateTime createdAt;
  final String? subscriptionType; // null | 'basic' | 'premium'
  final DateTime? subscriptionExpiry;

  AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.level,
    required this.walletBalance,
    required this.avatarEmoji,
    required this.isAdmin,
    required this.friendIds,
    required this.blockedIds,
    required this.createdAt,
    this.subscriptionType,
    this.subscriptionExpiry,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    int? level,
    double? walletBalance,
    String? avatarEmoji,
    List<String>? friendIds,
    List<String>? blockedIds,
    String? subscriptionType,
    DateTime? subscriptionExpiry,
  }) =>
      AppUser(
        id: id,
        email: email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        level: level ?? this.level,
        walletBalance: walletBalance ?? this.walletBalance,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        isAdmin: isAdmin,
        friendIds: friendIds ?? this.friendIds,
        blockedIds: blockedIds ?? this.blockedIds,
        createdAt: createdAt,
        subscriptionType: subscriptionType ?? this.subscriptionType,
        subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'level': level,
        'walletBalance': walletBalance,
        'avatarEmoji': avatarEmoji,
        'isAdmin': isAdmin,
        'friendIds': friendIds,
        'blockedIds': blockedIds,
        'createdAt': createdAt.toIso8601String(),
        'subscriptionType': subscriptionType,
        'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'],
        email: m['email'],
        firstName: m['firstName'],
        lastName: m['lastName'],
        phone: m['phone'] ?? '',
        level: m['level'] ?? 1,
        walletBalance: (m['walletBalance'] as num?)?.toDouble() ?? 0.0,
        avatarEmoji: m['avatarEmoji'] ?? '🎾',
        isAdmin: m['isAdmin'] ?? false,
        friendIds: List<String>.from(m['friendIds'] ?? []),
        blockedIds: List<String>.from(m['blockedIds'] ?? []),
        createdAt: DateTime.parse(m['createdAt']),
        subscriptionType: m['subscriptionType'],
        subscriptionExpiry: m['subscriptionExpiry'] != null
            ? DateTime.parse(m['subscriptionExpiry'])
            : null,
      );
}

const List<String> avatarEmojis = [
  '🎾', '🏆', '⚡', '🔥', '🌟', '🦁', '🐯', '🦅',
  '🏅', '💪', '🎯', '🚀',
];

const List<String> levelLabels = [
  '',
  'Débutant',
  'Novice',
  'Intermédiaire-',
  'Intermédiaire',
  'Intermédiaire+',
  'Avancé',
  'Expert',
  'Pro',
];
