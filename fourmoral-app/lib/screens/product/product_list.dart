import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/screens/product/media_slider.dart';
import 'package:fourmoral/screens/product/product_edit.dart';

class UserProductsPage extends StatelessWidget {
  const UserProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Products')),
        body: const Center(child: Text('Please login to view your products')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductEditPage(userId: user.uid),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildProductsList(user.uid)),
    );
  }

  Widget _buildProductsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('Products')
              .where('userId', isEqualTo: userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading products: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No products found. Add your first product!',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        try {
          final products =
              snapshot.data!.docs.map((doc) {
                return Product.fromMap(
                  id: doc.id,
                  data: doc.data() as Map<String, dynamic>,
                );
              }).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductItem(context, product);
            },
          );
        } catch (e) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error parsing products: $e',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildProductItem(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (product.mediaUrls.isNotEmpty)
            MediaSlider(mediaItems: product.mediaUrls)
          else
            Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.image, size: 50)),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.priceRange,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 8),

                if (product.variants.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Variants:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              product.variants.map((variant) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text(
                                      variant.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    backgroundColor:
                                        variant.isSwatch &&
                                                variant.colorHex != null
                                            ? _parseColor(variant.colorHex!)
                                            : Colors.grey[200],
                                    labelStyle: TextStyle(
                                      color:
                                          variant.isSwatch &&
                                                  variant.colorHex != null
                                              ? _getContrastColor(
                                                _parseColor(variant.colorHex!),
                                              )
                                              : Colors.black,
                                    ),
                                    avatar:
                                        variant.imageUrl != null &&
                                                !variant.isSwatch
                                            ? CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                variant.imageUrl!,
                                              ),
                                            )
                                            : null,
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit product',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ProductEditPage(
                                    existingProduct: product,
                                    userId: product.userId,
                                  ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete product',
                        onPressed: () => _deleteProduct(context, product.id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor";
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Color _getContrastColor(Color color) {
    double luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _deleteProduct(BuildContext context, String productId) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Product'),
                content: const Text(
                  'Are you sure you want to delete this product?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirmed) {
      try {
        await FirebaseFirestore.instance
            .collection('Products')
            .doc(productId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete product: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }
}
