import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/screens/mapScreen/map_screen_2.dart';
import 'package:fourmoral/screens/product/product_list.dart';
import 'package:fourmoral/screens/product/product_service.dart';
import 'package:fourmoral/screens/product/product_view_page.dart';
import 'package:fourmoral/screens/searchScreen/search_screen.dart';
import 'package:fourmoral/widgets/box_decoration_widget.dart';
import 'package:get/get.dart';
import 'package:video_compress/video_compress.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final ProductService _productService = ProductService();
  final Map<String, String?> _videoThumbnails = {};
  @override
  void initState() {
    super.initState();
    VideoCompress.setLogLevel(0);
  }

  @override
  void dispose() {
    VideoCompress.dispose();
    super.dispose();
  }

  void _navigateToEditProduct() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add products')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProductsPage()),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      await _productService.deleteProduct(product.id);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting product: $e')));
    }
  }

  Future<String?> _getVideoThumbnail(String videoUrl) async {
    if (_videoThumbnails.containsKey(videoUrl)) {
      return _videoThumbnails[videoUrl];
    }

    try {
      try {
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          videoUrl,
          quality: 50,
          position: 0,
        ).timeout(const Duration(seconds: 5));

        if (thumbnailFile.existsSync()) {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          if (thumbnailBytes.isNotEmpty) {
            final thumbnailPath = await _productService.uploadThumbnail(
              thumbnailBytes,
              '${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            _videoThumbnails[videoUrl] = thumbnailPath;
            return thumbnailPath;
          }
        }
      } catch (e) {
        debugPrint('Video_compress failed for $videoUrl: $e');
      }

      _videoThumbnails[videoUrl] = 'assets/video_placeholder.jpg';
      return 'assets/video_placeholder.jpg';
    } catch (e) {
      debugPrint('Complete thumbnail failure for $videoUrl: $e');
      return null;
    }
  }

  Widget _buildPlaceholder(Widget child) {
    return Container(color: Colors.grey[200], child: Center(child: child));
  }

  Widget _buildMediaPreview(Product product) {
    if (product.mediaUrls.isEmpty) {
      return _buildPlaceholder(const Icon(Icons.image_not_supported));
    }

    final firstMedia = product.mediaUrls.first;

    if (firstMedia.type == 'video') {
      return FutureBuilder<String?>(
        future: _getVideoThumbnail(firstMedia.url),
        builder: (context, snapshot) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (snapshot.hasData && snapshot.data != null)
                CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildVideoPlaceholder(),
                  errorWidget:
                      (context, url, error) => _buildVideoPlaceholder(),
                )
              else
                _buildVideoPlaceholder(),

              const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          );
        },
      );
    } else {
      return CachedNetworkImage(
        imageUrl: firstMedia.url,
        fit: BoxFit.cover,
        placeholder:
            (context, url) =>
                _buildPlaceholder(const CircularProgressIndicator()),
        errorWidget:
            (context, url, error) =>
                _buildPlaceholder(const Icon(Icons.broken_image)),
      );
    }
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 40, color: Colors.grey[600]),
            SizedBox(height: 8),
            Text(
              'Video Preview',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: height * 0.08,
              width: width,
              decoration: boxDecorationWidget(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AutoSizeText(
                          'Moral 1',
                          style: TextStyle(
                            color: black,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 08,
                              ),
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text('Note'),
                                          content: const Text(
                                            'Shop only your nearby business accounts like shops,  office and other business post and products show here..',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: const Text('Okay'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                child: Center(
                                  child: Image.asset(
                                    'assets/info.png',
                                    height: 28,
                                  ),
                                ),
                              ),
                            ),

                            iconButton(
                              context,
                              width,
                              () => _navigateToEditProduct(),
                              Image.asset(
                                'assets/price-tag.png',
                                width: 18,
                                height: 18,
                              ),
                              0.06,
                              null,
                            ),
                            const SizedBox(width: 10),
                            iconButton(
                              context,
                              width,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SearchScreen(),
                                  ),
                                );
                              },
                              Image.asset(
                                'assets/search.png',
                                width: 24,
                                height: 24,
                              ),
                              0.08,
                              null,
                            ),
                            const SizedBox(width: 10),
                            iconButton(
                              context,
                              width,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MapScreen3(),
                                  ),
                                );
                              },
                              Image.asset(
                                'assets/earth.png',
                                width: 24,
                                height: 24,
                              ),
                              0.08,
                              null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _productService.getProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = snapshot.data ?? [];

                  if (products.isEmpty) {
                    return const Center(
                      child: Text('No products.', textAlign: TextAlign.center),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      itemCount: (products.length / 5).ceil(),
                      itemBuilder: (context, patternIndex) {
                        final startIndex = patternIndex * 5;
                        final remainingItems = products.length - startIndex;

                        return Column(
                          children: [
                            if (remainingItems > 0)
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: _buildProductItem(
                                      context,
                                      products[startIndex],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child:
                                        remainingItems > 1
                                            ? _buildProductItem(
                                              context,
                                              products[startIndex + 1],
                                            )
                                            : const SizedBox(),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),

                            if (remainingItems > 2)
                              _buildFullWidthProductItem(
                                context,
                                products[startIndex + 2],
                              ),
                            const SizedBox(height: 10),

                            if (remainingItems > 3)
                              SizedBox(
                                height: MediaQuery.of(context).size.width * 0.5,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: SizedBox(
                                        height: double.infinity,
                                        child: _buildProductItem(
                                          context,
                                          products[startIndex + 3],
                                          aspectRatio: 3 / 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child:
                                          remainingItems > 4
                                              ? SizedBox(
                                                height: double.infinity,
                                                child: _buildProductItem(
                                                  context,
                                                  products[startIndex + 4],
                                                  aspectRatio: 1 / 2,
                                                ),
                                              )
                                              : const SizedBox(),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(
    BuildContext context,
    Product product, {
    double aspectRatio = 1.0,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductViewPage(productId: product.id),
                ),
              ).then((_) {
                // This ensures the controller is disposed when popping the route
                Get.delete<ProductViewController>(tag: product.id);
              }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildMediaPreview(product),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthProductItem(BuildContext context, Product product) {
    return AspectRatio(
      aspectRatio: 2.0,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductViewPage(productId: product.id),
                ),
              ).then((_) {
                // This ensures the controller is disposed when popping the route
                Get.delete<ProductViewController>(tag: product.id);
              }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildMediaPreview(product),
          ),
        ),
      ),
    );
  }
}
