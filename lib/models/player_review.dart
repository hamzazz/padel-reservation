class PlayerReview {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String reviewerEmoji;
  final String targetId;
  final double rating; // 1.0 - 5.0
  final String comment;
  final DateTime createdAt;

  PlayerReview({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerEmoji,
    required this.targetId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'reviewerEmoji': reviewerEmoji,
        'targetId': targetId,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlayerReview.fromMap(Map<String, dynamic> m) => PlayerReview(
        id: m['id'],
        reviewerId: m['reviewerId'],
        reviewerName: m['reviewerName'],
        reviewerEmoji: m['reviewerEmoji'] ?? '🎾',
        targetId: m['targetId'],
        rating: (m['rating'] as num).toDouble(),
        comment: m['comment'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}
