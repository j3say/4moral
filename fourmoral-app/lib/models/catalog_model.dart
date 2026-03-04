// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

class Catalog {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final String userId;
  final List<CatalogItem> items;

  Catalog({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.userId,
    this.items = const [],
  });

  factory Catalog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Catalog(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Catalog',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'],
      items:
          (data['items'] as List<dynamic>? ?? [])
              .map((item) => CatalogItem.fromMap(item))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}

class CatalogItem {
  final String itemId;
  final String type; // 'product' or 'post'
  final DateTime savedAt;

  CatalogItem({
    required this.itemId,
    required this.type,
    required this.savedAt,
  });

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    return CatalogItem(
      itemId: map['itemId'],
      type: map['type'],
      savedAt: (map['savedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'type': type,
      'savedAt': Timestamp.fromDate(savedAt),
    };
  }
}
