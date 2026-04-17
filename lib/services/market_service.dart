import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';

class MarketService {
  final _col = FirebaseFirestore.instance.collection('products');

  Future<List<Product>> getAll({String? category, bool? isNew}) async {
    Query<Map<String, dynamic>> q =
        _col.where('isSold', isEqualTo: false).orderBy('createdAt', descending: true);
    if (category != null) q = q.where('category', isEqualTo: category);
    if (isNew != null) q = q.where('isNew', isEqualTo: isNew);
    final snap = await q.get();
    return snap.docs.map((d) => Product.fromMap(_ts(d.data()))).toList();
  }

  Future<List<Product>> getByUser(String userId) async {
    final snap = await _col
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => Product.fromMap(_ts(d.data()))).toList();
  }

  Future<Product> addProduct({
    required String sellerId,
    required String sellerName,
    required String sellerEmoji,
    required String title,
    required String description,
    required double price,
    required bool isNew,
    required String category,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final product = Product(
      id: id,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerEmoji: sellerEmoji,
      title: title,
      description: description,
      price: price,
      isNew: isNew,
      category: category,
      isSold: false,
      createdAt: now,
    );
    await _col.doc(id).set({
      ...product.toMap(),
      'createdAt': Timestamp.fromDate(now),
    });
    return product;
  }

  Future<void> markSold(String productId) async {
    await _col.doc(productId).update({'isSold': true});
  }

  Future<void> delete(String productId) async {
    await _col.doc(productId).delete();
  }

  static Map<String, dynamic> _ts(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }
}
