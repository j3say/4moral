import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/product_model.dart';
import 'dart:io';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collectionName = 'Products';

  // Optimized to upload files concurrently using Future.wait
  Future<List<ProductMedia>> uploadMediaFiles(
    List<File> files,
    String productId,
  ) async {
    try {
      // Create a list to store all upload futures
      final List<Future<ProductMedia>> uploadFutures = [];

      // Start all uploads concurrently
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final filename = '${DateTime.now().millisecondsSinceEpoch}_$i';
        final ref = _storage.ref('product_media/$productId/$filename');

        // Create an upload task
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: _getContentType(file.path),
            customMetadata: {'productId': productId},
          ),
        );

        // Add event listener for progress tracking if needed
        // uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        //   final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        //   // Update UI with progress if needed
        // });

        // Create a future that will complete when the upload is done
        final mediaFuture = uploadTask.then((_) async {
          final url = await ref.getDownloadURL();
          final isVideo =
              file.path.endsWith('.mp4') || file.path.endsWith('.mov');
          return ProductMedia(url: url, type: isVideo ? 'video' : 'image');
        });

        uploadFutures.add(mediaFuture);
      }

      // Wait for all uploads to complete
      final media = await Future.wait(uploadFutures);
      return media;
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  String _getContentType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.mov')) return 'video/quicktime';
    return 'application/octet-stream';
  }

  Future<void> deleteMedia(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting media: $e');
    }
  }

  // Batch delete multiple media files for better performance
  Future<void> deleteMediaBatch(List<String> urls) async {
    if (urls.isEmpty) return;

    final deleteFutures = urls.map((url) async {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting media: $e');
      }
    });

    await Future.wait(deleteFutures);
  }

  Stream<List<Product>> getUserProductsStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Product.fromMap(id: doc.id, data: doc.data()))
                  .toList(),
        );
  }

  // Optimized to handle media uploads concurrently
  Future<void> addProduct(Product product, {List<File>? mediaFiles}) async {
    try {
      // Handle media uploads if present (concurrent)
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        product.mediaUrls = await uploadMediaFiles(mediaFiles, product.id);
      }

      // Add product to Firestore
      await _firestore
          .collection(_collectionName)
          .doc(product.id)
          .set(product.toMap());
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<String> uploadThumbnail(
    Uint8List thumbnailData,
    String fileName,
  ) async {
    try {
      final ref = _storage.ref('thumbnails/$fileName');

      // Optimize metadata for the upload
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );

      // Start upload
      await ref.putData(thumbnailData, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload thumbnail: $e');
    }
  }

  // Optimized update method
  Future<void> updateProduct(
    Product product, {
    List<File>? newMediaFiles,
    List<ProductMedia>? mediaUrlsToKeep,
    List<String>? mediaUrlsToDelete,
  }) async {
    try {
      final List<Future> operations = [];

      // Operation 1: Delete old media if needed
      if (mediaUrlsToDelete != null && mediaUrlsToDelete.isNotEmpty) {
        operations.add(deleteMediaBatch(mediaUrlsToDelete));
      }

      // Operation 2: Upload new media if needed
      Future<List<ProductMedia>>? newMediaFuture;
      if (newMediaFiles != null && newMediaFiles.isNotEmpty) {
        newMediaFuture = uploadMediaFiles(newMediaFiles, product.id);
        operations.add(newMediaFuture);
      }

      // Wait for all operations to complete
      await Future.wait(operations);

      // Update product with new media URLs
      if (newMediaFuture != null) {
        final newUrls = await newMediaFuture;
        product.mediaUrls = [...(mediaUrlsToKeep ?? []), ...newUrls];
      } else {
        product.mediaUrls = mediaUrlsToKeep ?? [];
      }

      // Update product in Firestore
      await _firestore
          .collection(_collectionName)
          .doc(product.id)
          .update(product.toMap());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      // Get the product to find all media URLs
      final product = await getProductById(productId);

      final List<Future> operations = [];

      // Operation 1: Delete all media if present
      if (product != null && product.mediaUrls.isNotEmpty) {
        final mediaUrls = product.mediaUrls.map((media) => media.url).toList();
        operations.add(deleteMediaBatch(mediaUrls));
      }

      // Operation 2: Delete product from Firestore
      operations.add(
        _firestore.collection(_collectionName).doc(productId).delete(),
      );

      // Operation 3: Delete product image if exists
      operations.add(_deleteImage(productId));

      // Execute all operations concurrently
      await Future.wait(operations);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Stream<List<Product>> getProductsStream() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Product.fromMap(id: doc.id, data: doc.data()))
                  .toList(),
        );
  }

  Stream<Product?> getProductStream(String productId) {
    return _firestore
        .collection(_collectionName)
        .doc(productId)
        .snapshots()
        .map(
          (doc) =>
              doc.exists
                  ? Product.fromMap(id: doc.id, data: doc.data()!)
                  : null,
        );
  }

  Stream<List<Product>> getFilteredProductsStream({
    double? minPrice,
    double? maxPrice,
    int? minStock,
    String? category,
    int? limit,
  }) {
    Query query = _firestore.collection(_collectionName);

    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }
    if (minStock != null) {
      query = query.where('stockQuantity', isGreaterThanOrEqualTo: minStock);
    }
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => Product.fromMap(
                  id: doc.id,
                  data: doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      return doc.exists ? Product.fromMap(id: doc.id, data: doc.data()!) : null;
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  Future<String> _uploadImage(File imageFile, String productId) async {
    try {
      final ref = _storage.ref('product_images/$productId');
      final metadata = SettableMetadata(
        contentType: _getContentType(imageFile.path),
        cacheControl: 'public, max-age=31536000',
      );
      await ref.putFile(imageFile, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _deleteImage(String productId) async {
    try {
      final ref = _storage.ref('product_images/$productId');
      final exists = await ref
          .getMetadata()
          .then((_) => true)
          .catchError((_) => false);
      if (exists) {
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');

      if (!e.toString().contains('object-not-found')) {
        throw Exception('Failed to delete image: $e');
      }
    }
  }

  Map<String, dynamic> _processVariantData(ProductVariant variant) {
    return {
      'id': variant.id,
      'name': variant.name,
      'weight': variant.weight,
      'height': variant.height,
      'priceAdjustment': variant.priceAdjustment,
      'stockQuantity': variant.stockQuantity,
    };
  }
}
