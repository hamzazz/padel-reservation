class Product {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerEmoji;
  final String sellerPhone;
  final String title;
  final String description;
  final double price;
  final bool isNew;
  final String category;
  bool isSold;
  final DateTime createdAt;
  final String? imageUrl;

  Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerEmoji,
    this.sellerPhone = '',
    required this.title,
    required this.description,
    required this.price,
    required this.isNew,
    required this.category,
    required this.isSold,
    required this.createdAt,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerEmoji': sellerEmoji,
        'sellerPhone': sellerPhone,
        'title': title,
        'description': description,
        'price': price,
        'isNew': isNew,
        'category': category,
        'isSold': isSold,
        'createdAt': createdAt.toIso8601String(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'],
        sellerId: m['sellerId'],
        sellerName: m['sellerName'],
        sellerEmoji: m['sellerEmoji'] ?? '🎾',
        sellerPhone: m['sellerPhone'] as String? ?? '',
        title: m['title'],
        description: m['description'],
        price: (m['price'] as num).toDouble(),
        isNew: m['isNew'] ?? true,
        category: m['category'],
        isSold: m['isSold'] ?? false,
        createdAt: DateTime.parse(m['createdAt']),
        imageUrl: m['imageUrl'] as String?,
      );
}

const List<String> productCategories = [
  'Raquette',
  'Chaussures',
  'Balles',
  'Sac',
  'Tenue',
  'Protège-poignet',
  'Grip',
  'Autre',
];
