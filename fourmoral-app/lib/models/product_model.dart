import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductMedia {
  final String url;
  final String type;

  ProductMedia({required this.url, required this.type});

  Map<String, dynamic> toMap() {
    return {'url': url, 'type': type};
  }

  factory ProductMedia.fromMap(Map<String, dynamic> map) {
    return ProductMedia(url: map['url'], type: map['type'] ?? 'image');
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final double? comparedAtPrice;
  List<ProductMedia> mediaUrls;
  int totalStockQuantity;
  final DateTime? createdAt;
  final String? category;
  final List<ProductVariant> variants;
  final String userId;
  final String currency;

  Product({
    String? id,
    required this.name,
    this.description = '',
    required this.basePrice,
    this.comparedAtPrice,
    this.mediaUrls = const [],
    this.totalStockQuantity = 0,
    this.createdAt,
    this.category,
    this.variants = const [],
    required this.userId,
    this.currency = 'INR',
  }) : id = id ?? _generateId();

  int get calculatedStock =>
      variants.fold(0, (sum, variant) => sum + variant.stockQuantity);

  String get priceRange {
    if (variants.isEmpty) return '₹\${basePrice.toStringAsFixed(2)}';

    final minPrice = variants.fold(
      basePrice + variants.first.priceAdjustment,
      (min, variant) =>
          min < basePrice + variant.priceAdjustment
              ? min
              : basePrice + variant.priceAdjustment,
    );

    final maxPrice = variants.fold(
      basePrice + variants.first.priceAdjustment,
      (max, variant) =>
          max > basePrice + variant.priceAdjustment
              ? max
              : basePrice + variant.priceAdjustment,
    );

    return minPrice == maxPrice
        ? '\$${minPrice.toStringAsFixed(2)}'
        : '\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}';
  }

  static String _generateId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(1000).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'basePrice': basePrice,
      'comparedAtPrice': comparedAtPrice,
      'mediaUrls': mediaUrls.map((m) => m.toMap()).toList(),
      'totalStockQuantity': totalStockQuantity,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'category': category,
      'variants': variants.map((v) => v.toMap()).toList(),
      'userId': userId,
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      basePrice: (data['basePrice'] ?? data['price'] ?? 0.0).toDouble(),
      mediaUrls:
          (data['mediaUrls'] as List<dynamic>? ?? [])
              .map((m) => ProductMedia.fromMap(m))
              .toList(),
      totalStockQuantity:
          data['totalStockQuantity'] ?? data['stockQuantity'] ?? 0,
      createdAt: data['createdAt']?.toDate(),
      category: data['category'],
      variants:
          (data['variants'] as List<dynamic>? ?? [])
              .map((v) => ProductVariant.fromMap(v))
              .toList(),
      userId: data['userId'] ?? '',
      currency: data['currency'] ?? 'INR',
    );
  }

  factory Product.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      basePrice: (data['basePrice'] ?? data['price'] ?? 0.0).toDouble(),
      comparedAtPrice: data['comparedAtPrice']?.toDouble(),
      mediaUrls:
          (data['mediaUrls'] as List<dynamic>? ?? [])
              .map((m) => ProductMedia.fromMap(m))
              .toList(),
      totalStockQuantity:
          data['totalStockQuantity'] ?? data['stockQuantity'] ?? 0,
      createdAt: data['createdAt']?.toDate(),
      category: data['category'],
      variants:
          (data['variants'] as List<dynamic>? ?? [])
              .map((v) => ProductVariant.fromMap(v))
              .toList(),
      userId: data['userId'] ?? '',
      currency: data['currency'] ?? 'INR',
    );
  }

  List<String> get imageUrls =>
      mediaUrls.where((m) => m.type == 'image').map((m) => m.url).toList();

  List<String> get videoUrls =>
      mediaUrls.where((m) => m.type == 'video').map((m) => m.url).toList();
}

class ProductVariant {
  final String id;
  final String name;
  final double? weight;
  final double? height;
  final double priceAdjustment;
  final int stockQuantity;
  final String? imageUrl;
  final String? colorHex;
  final bool isSwatch;

  ProductVariant({
    String? id,
    required this.name,
    this.weight,
    this.height,
    this.priceAdjustment = 0.0,
    this.stockQuantity = 0,
    this.imageUrl,
    this.colorHex,
    this.isSwatch = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'height': height,
      'priceAdjustment': priceAdjustment,
      'stockQuantity': stockQuantity,
      'imageUrl': imageUrl,
      'colorHex': colorHex,
      'isSwatch': isSwatch,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> data) {
    return ProductVariant(
      id: data['id']?.toString() ?? '',
      name: data['name'] ?? '',
      weight: data['weight']?.toDouble(),
      height: data['height']?.toDouble(),
      priceAdjustment: (data['priceAdjustment'] ?? 0.0).toDouble(),
      stockQuantity: (data['stockQuantity'] ?? 0).toInt(),
      imageUrl: data['imageUrl'],
      colorHex: data['colorHex'],
      isSwatch: data['isSwatch'] ?? false,
    );
  }
}
