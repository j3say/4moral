import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/catalog_model.dart';

class CatalogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all catalogs for a user
  Stream<List<Catalog>> getUserCatalogs(String userId) {
    return _firestore
        .collection('catalogs')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Catalog.fromFirestore(doc)).toList(),
        );
  }

  // Create a new catalog
  Future<Catalog> createCatalog({
    required String userId,
    required String name,
    String? description,
  }) async {
    final docRef = _firestore.collection('catalogs').doc();
    final catalog = Catalog(
      id: docRef.id,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      userId: userId,
    );
    await docRef.set(catalog.toMap());
    return catalog;
  }

  // Add an item to a catalog
  Future<void> addItemToCatalog({
    required String catalogId,
    required String itemId,
    required String type,
  }) async {
    final item = CatalogItem(
      itemId: itemId,
      type: type,
      savedAt: DateTime.now(),
    );

    await _firestore.collection('catalogs').doc(catalogId).update({
      'items': FieldValue.arrayUnion([item.toMap()]),
    });
  }

  // Remove an item from a catalog
  Future<void> removeItemFromCatalog({
    required String catalogId,
    required String itemId,
    required String type,
  }) async {
    final catalogDoc =
        await _firestore.collection('catalogs').doc(catalogId).get();
    final catalog = Catalog.fromFirestore(catalogDoc);

    final itemToRemove = catalog.items.firstWhere(
      (item) => item.itemId == itemId && item.type == type,
      orElse: () => throw Exception('Item not found in catalog'),
    );

    await _firestore.collection('catalogs').doc(catalogId).update({
      'items': FieldValue.arrayRemove([itemToRemove.toMap()]),
    });
  }

  // Delete a catalog
  Future<void> deleteCatalog(String catalogId) async {
    await _firestore.collection('catalogs').doc(catalogId).delete();
  }
}
