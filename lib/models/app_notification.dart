class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  // types: 'match_join' | 'match_completed' | 'match_cancelled'
  //        | 'friend_request' | 'new_player' | 'payment' | 'tournament'
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  String get icon {
    switch (type) {
      case 'match_join':
        return '🎾';
      case 'match_completed':
        return '✅';
      case 'match_cancelled':
        return '❌';
      case 'friend_request':
        return '👥';
      case 'new_player':
        return '🆕';
      case 'payment':
        return '💳';
      case 'tournament':
        return '🏆';
      default:
        return '🔔';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'],
        userId: m['userId'],
        title: m['title'],
        body: m['body'],
        type: m['type'],
        isRead: m['isRead'] ?? false,
        createdAt: DateTime.parse(m['createdAt']),
      );
}
