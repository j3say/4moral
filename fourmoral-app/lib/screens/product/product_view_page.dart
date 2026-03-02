import 'package:carousel_slider/carousel_slider.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/screens/checkoutScreen/checkout_screen.dart';
import 'package:fourmoral/screens/product/product_service.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class ProductViewController extends GetxController {
  final ProductService _productService = ProductService();
  String productId;

  final Rx<Product?> product = Rx<Product?>(null);
  final RxBool isLoading = true.obs;
  final RxInt selectedMediaIndex = 0.obs;
  final RxInt selectedVariantIndex = 0.obs;
  final RxInt quantity = 1.obs;
  final RxDouble rating = 0.0.obs;

  late final Stream<Product?> _productStream;

  ProductViewController(this.productId) {
    _productStream = _productService.getProductStream(productId);
  }

  @override
  void onInit() {
    super.onInit();
    _loadProduct();
  }

  void updateProductId(String newProductId) {
    if (productId != newProductId) {
      productId = newProductId;
      _loadProduct(); // Reload product when ID changes
    }
  }

  void _loadProduct() {
    isLoading.value = true;
    _productStream.listen(
      (productData) {
        product.value = productData;
        isLoading.value = false;

        // Reset selected variant if needed
        if (product.value != null &&
            product.value!.variants.isNotEmpty &&
            selectedVariantIndex.value >= product.value!.variants.length) {
          selectedVariantIndex.value = 0;
        }
      },
      onError: (error) {
        print('Error loading product: $error');
        isLoading.value = false;
      },
    );
  }

  void selectVariant(int index) {
    if (index >= 0 &&
        product.value != null &&
        index < product.value!.variants.length) {
      selectedVariantIndex.value = index;
    }
  }

  void incrementQuantity() {
    quantity.value++;
  }

  void decrementQuantity() {
    if (quantity.value > 1) {
      quantity.value--;
    }
  }

  bool get hasDiscount {
    if (product.value == null) return false;
    return product.value!.comparedAtPrice != null &&
        product.value!.comparedAtPrice! > product.value!.basePrice;
  }

  double get discountPercentage {
    if (!hasDiscount) return 0.0;
    return ((product.value!.comparedAtPrice! - product.value!.basePrice) /
            product.value!.comparedAtPrice!) *
        100;
  }

  double get currentPrice {
    if (product.value == null) return 0.0;

    double basePrice = product.value!.basePrice;
    if (product.value!.variants.isNotEmpty &&
        selectedVariantIndex.value < product.value!.variants.length) {
      basePrice +=
          product.value!.variants[selectedVariantIndex.value].priceAdjustment;
    }

    return basePrice * quantity.value;
  }

  String get currencySymbol {
    if (product.value == null) return '₹';

    final Map<String, String> currencySymbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'AUD': '\$',
      'CAD': '\$',
      'CHF': 'Fr',
      'CNY': '¥',
      'DKK': 'kr',
      'HKD': '\$',
      'MXN': '\$',
      'NOK': 'kr',
      'NZD': '\$',
      'SEK': 'kr',
      'SGD': '\$',
      'ZAR': 'R',
    };

    return currencySymbols[product.value!.currency] ?? '₹';
  }

  int get currentStock {
    if (product.value == null) return 0;

    if (product.value!.variants.isNotEmpty &&
        selectedVariantIndex.value < product.value!.variants.length) {
      return product.value!.variants[selectedVariantIndex.value].stockQuantity;
    }

    return 0; // Default if no variants or stock info
  }

  void submitRating(double value) {
    rating.value = value;
    // Here you would implement saving the rating to your database
  }

  Future<void> addToCart() async {
    if (product.value == null) return;

    // Implement your cart functionality here
    // For example, using GetX or shared preferences

    Get.snackbar(
      'Added to Cart',
      '${product.value!.name} added to your cart',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  Future<void> buyNow() async {
    if (product.value == null) return;

    // Implement your direct checkout functionality here
    // For example, navigate to checkout page

    Get.toNamed(
      '/checkout',
      arguments: {
        'product': product.value,
        'variant':
            product.value!.variants.isNotEmpty
                ? product.value!.variants[selectedVariantIndex.value]
                : null,
        'quantity': quantity.value,
      },
    );
  }
}

class ProductViewPage extends StatefulWidget {
  final String productId;

  const ProductViewPage({super.key, required this.productId});

  @override
  _ProductViewPageState createState() => _ProductViewPageState();
}

class _ProductViewPageState extends State<ProductViewPage> {
  late ProductViewController controller;
  Map<String, ChewieController?> videoControllers = {};

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      ProductViewController(widget.productId),
      tag: widget.productId,
    );
  }

  @override
  void didUpdateWidget(ProductViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      // Update controller with new product ID
      controller.updateProductId(widget.productId);

      // Dispose all video controllers for the old product
      videoControllers.forEach((key, controller) {
        controller?.dispose();
      });
      videoControllers.clear();
    }
  }

  @override
  void dispose() {
    // Dispose all video controllers
    videoControllers.forEach((key, controller) {
      controller?.dispose();
    });
    super.dispose();
  }

  Future<ChewieController?> _initializeVideoPlayer(String url) async {
    if (videoControllers.containsKey(url) && videoControllers[url] != null) {
      return videoControllers[url];
    }

    try {
      final videoPlayerController = VideoPlayerController.network(url);
      await videoPlayerController.initialize();

      final chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        autoPlay: false,
        looping: false,
        aspectRatio: videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      videoControllers[url] = chewieController;
      return chewieController;
    } catch (e) {
      print('Error initializing video player: $e');
      return null;
    }
  }

  Widget _buildMediaCarousel(List<ProductMedia> mediaUrls) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 250,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              controller.selectedMediaIndex.value = index;
            },
          ),
          items:
              mediaUrls.map((media) {
                if (media.type == 'video') {
                  return FutureBuilder<ChewieController?>(
                    future: _initializeVideoPlayer(media.url),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError || snapshot.data == null) {
                        return Center(
                          child: Icon(
                            Icons.videocam_off,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      } else {
                        return Chewie(controller: snapshot.data!);
                      }
                    },
                  );
                } else {
                  return Image.network(
                    media.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  );
                }
              }).toList(),
        ),
        SizedBox(height: 10),
        // Thumbnail indicators
        if (mediaUrls.length > 1)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mediaUrls.length,
              itemBuilder: (context, index) {
                final media = mediaUrls[index];
                return Obx(
                  () => GestureDetector(
                    onTap: () => controller.selectedMediaIndex.value = index,
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              controller.selectedMediaIndex.value == index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child:
                          media.type == 'video'
                              ? Icon(Icons.play_circle_fill, color: Colors.grey)
                              : Image.network(
                                media.url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVariantSelector(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.variants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Variants',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: product.variants.length,
              itemBuilder: (context, index) {
                final variant = product.variants[index];
                return Obx(
                  () => GestureDetector(
                    onTap: () => controller.selectVariant(index),
                    child: Container(
                      width: 70,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              controller.selectedVariantIndex.value == index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (variant.isSwatch && variant.colorHex != null)
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse('0xFF${variant.colorHex}'),
                                ),
                                shape: BoxShape.circle,
                              ),
                            )
                          else if (variant.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                variant.imageUrl!,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    size: 30,
                                  );
                                },
                              ),
                            ),
                          SizedBox(height: 4),
                          Text(
                            variant.name,
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text(
          'Quantity:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: controller.decrementQuantity,
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
                iconSize: 18,
              ),
              Obx(
                () => Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${controller.quantity.value}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: controller.incrementQuantity,
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
                iconSize: 18,
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Obx(
          () => Text(
            'Stock: ${controller.currentStock}',
            style: TextStyle(
              color: controller.currentStock > 5 ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate this product:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Row(
          children: [
            RatingBar.builder(
              initialRating: controller.rating.value,
              minRating: 0,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 24,
              itemBuilder:
                  (context, _) => Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                controller.submitRating(rating);
              },
            ),
            SizedBox(width: 8),
            Obx(
              () => Text(
                controller.rating.value > 0
                    ? controller.rating.value.toStringAsFixed(1)
                    : "Not rated",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Implement share functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite_border),
            onPressed: () {
              // Implement wishlist functionality
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        final product = controller.product.value;
        if (product == null) {
          return Center(child: Text('Product not found'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Carousel
              if (product.mediaUrls.isNotEmpty)
                _buildMediaCarousel(product.mediaUrls),

              // Product Details
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Price
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Obx(() {
                          final hasDiscount = controller.hasDiscount;
                          final basePrice = controller.currentPrice;
                          final comparedPrice =
                              controller.product.value?.comparedAtPrice != null
                                  ? controller.product.value!.comparedAtPrice! *
                                      controller.quantity.value
                                  : basePrice;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${controller.currencySymbol}${comparedPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      hasDiscount
                                          ? Colors.red
                                          : Theme.of(context).primaryColor,
                                ),
                              ),
                              if (hasDiscount) ...[
                                Text(
                                  '${controller.currencySymbol}${basePrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],

                              if (hasDiscount) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${controller.discountPercentage.toStringAsFixed(0)}% OFF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                        SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.category ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.category ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                    Divider(height: 24),

                    // Variant Selection
                    _buildVariantSelector(product),

                    SizedBox(height: 16),

                    // Quantity Selection
                    _buildQuantitySelector(),

                    SizedBox(height: 16),

                    // Add to Cart and Buy Now buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.shopping_cart),
                            label: Text('Add to Cart'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: controller.addToCart,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.flash_on),
                            label: Text('Buy Now'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: () {
                              Get.to(() => AmazonLikeCheckoutPage());
                              print('Buy Now pressed');
                            },
                            // onPressed: controller.buyNow,
                          ),
                        ),
                      ],
                    ),

                    Divider(height: 24),

                    // Product Description
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(product.description, style: TextStyle(fontSize: 16)),

                    SizedBox(height: 24),

                    // Product Specifications
                    if (product.variants.isNotEmpty) ...[
                      Text(
                        'Specifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Obx(() {
                        final variant =
                            product.variants[controller
                                .selectedVariantIndex
                                .value];
                        return Column(
                          children: [
                            if (variant.weight != null)
                              _specificationRow(
                                'Weight',
                                '${variant.weight} kg',
                              ),
                            if (variant.height != null)
                              _specificationRow(
                                'Height',
                                '${variant.height} cm',
                              ),
                            // Add more specifications as needed
                          ],
                        );
                      }),
                    ],

                    SizedBox(height: 24),

                    // Rating Section
                    _buildRatingSection(),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _specificationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
