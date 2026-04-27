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
  final bool isBlockedByAdmin;
  final bool isClubAdmin;
  final String clubId;

  final int eloRating;        // ELO score, starts at 1000
  final int eloMatchesPlayed;
  final int eloWins;

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
    this.isBlockedByAdmin = false,
    this.isClubAdmin = false,
    this.clubId = '',
    this.eloRating = 1000,
    this.eloMatchesPlayed = 0,
    this.eloWins = 0,
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
    bool? isBlockedByAdmin,
    bool? isClubAdmin,
    String? clubId,
    int? eloRating,
    int? eloMatchesPlayed,
    int? eloWins,
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
        isBlockedByAdmin: isBlockedByAdmin ?? this.isBlockedByAdmin,
        isClubAdmin: isClubAdmin ?? this.isClubAdmin,
        clubId: clubId ?? this.clubId,
        eloRating: eloRating ?? this.eloRating,
        eloMatchesPlayed: eloMatchesPlayed ?? this.eloMatchesPlayed,
        eloWins: eloWins ?? this.eloWins,
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
        'isBlockedByAdmin': isBlockedByAdmin,
        'isClubAdmin': isClubAdmin,
        'clubId': clubId,
        'eloRating': eloRating,
        'eloMatchesPlayed': eloMatchesPlayed,
        'eloWins': eloWins,
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
        isBlockedByAdmin: m['isBlockedByAdmin'] ?? false,
        isClubAdmin: m['isClubAdmin'] ?? false,
        clubId: m['clubId'] ?? '',
        eloRating: (m['eloRating'] as int?) ?? 1000,
        eloMatchesPlayed: (m['eloMatchesPlayed'] as int?) ?? 0,
        eloWins: (m['eloWins'] as int?) ?? 0,
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
