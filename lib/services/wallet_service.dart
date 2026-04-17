import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet_transaction.dart';

class WalletService {
  final _col = FirebaseFirestore.instance.collection('wallet_transactions');

  Future<List<WalletTransaction>> getTransactions(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => WalletTransaction.fromMap(_ts(d.data()))).toList();
  }

  Future<WalletTransaction> addTransaction({
    required String userId,
    required double amount,
    required String type,
    required String description,
  }) async {
    final tx = WalletTransaction(
      id: const Uuid().v4(),
      userId: userId,
      amount: amount,
      type: type,
      description: description,
      createdAt: DateTime.now(),
    );
    await _col.doc(tx.id).set({
      ...tx.toMap(),
      'createdAt': Timestamp.fromDate(tx.createdAt),
    });
    return tx;
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
