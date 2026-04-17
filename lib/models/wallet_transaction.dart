class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'recharge' | 'payment' | 'refund' | 'cancellation'
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  bool get isCredit => type == 'recharge' || type == 'refund';

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'type': type,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WalletTransaction.fromMap(Map<String, dynamic> m) =>
      WalletTransaction(
        id: m['id'],
        userId: m['userId'],
        amount: (m['amount'] as num).toDouble(),
        type: m['type'],
        description: m['description'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}
