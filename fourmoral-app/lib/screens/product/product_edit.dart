import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fourmoral/screens/product/recent_category_service.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/screens/product/product_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ProductEditPage extends StatefulWidget {
  final Product? existingProduct;
  final VoidCallback? onProductSaved;
  final String userId;
  final List<Map<String, String?>>? selectedMedia;

  const ProductEditPage({
    super.key,
    this.existingProduct,
    this.onProductSaved,
    required this.userId,
    this.selectedMedia,
  });

  @override
  _ProductEditPageState createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();
  final ImagePicker _picker = ImagePicker();
  final _recentService = RecentCategoryService.instance;
  final List<String> _allCategories = [
    'Electronics',
    'Clothing',
    'Furniture',
    'Food',
    'Books',
    'Toys',
    'Beauty',
    'Sports',
    'Other',
  ];

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _basePriceController;
  late TextEditingController _comparedAtPriceController;
  late TextEditingController _categoryController;

  final List<File> _mediaFiles = [];
  final List<String?> _mediaThumbnails = []; // Store thumbnail paths for videos
  List<ProductMedia> _mediaUrls = [];
  List<ProductMedia> _mediaUrlsToKeep = [];

  late List<TextEditingController> _variantNameControllers;
  late List<TextEditingController> _variantWeightControllers;
  late List<TextEditingController> _variantHeightControllers;
  late List<TextEditingController> _variantPriceAdjControllers;
  late List<TextEditingController> _variantStockControllers;
  late List<File?> _variantImageFiles;
  late List<String?> _variantImageUrls;
  late List<String?> _variantColorHexs;
  late List<bool> _variantIsSwatch;

  bool _isLoading = false;

  final List<String> currencies = [
    'INR', 'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY',
    'DKK', 'HKD', 'MXN', 'NOK', 'NZD', 'SEK', 'SGD', 'ZAR',
  ];
  final Map<String, String> currencySymbols = {
    'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
    'AUD': '\$', 'CAD': '\$', 'CHF': 'Fr', 'CNY': '¥', 'DKK': 'kr',
    'HKD': '\$', 'MXN': '\$', 'NOK': 'kr', 'NZD': '\$', 'SEK': 'kr',
    'SGD': '\$', 'ZAR': 'R',
  };
  late String selectedCurrency;

  @override
  void initState() {
    super.initState();
    final product = widget.existingProduct;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _basePriceController = TextEditingController(text: product?.basePrice.toString() ?? '');
    _comparedAtPriceController = TextEditingController(text: product?.comparedAtPrice?.toString() ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');

    selectedCurrency = product?.currency ?? 'INR';
    _mediaUrls = product?.mediaUrls.map((media) => media).toList() ?? [];
    _mediaUrlsToKeep = List.from(_mediaUrls);

    if (widget.selectedMedia != null && widget.selectedMedia!.isNotEmpty) {
      _mediaFiles.addAll(widget.selectedMedia!.map((media) => File(media['filePath']!)));
      _mediaThumbnails.addAll(widget.selectedMedia!.map((media) => media['thumbnailPath']));
    }

    _variantNameControllers = [];
    _variantWeightControllers = [];
    _variantHeightControllers = [];
    _variantPriceAdjControllers = [];
    _variantStockControllers = [];
    _variantImageFiles = [];
    _variantImageUrls = [];
    _variantColorHexs = [];
    _variantIsSwatch = [];

    if (product?.variants != null && product!.variants.isNotEmpty) {
      for (var variant in product.variants) {
        _variantNameControllers.add(TextEditingController(text: variant.name));
        _variantWeightControllers.add(TextEditingController(text: variant.weight?.toString() ?? ''));
        _variantHeightControllers.add(TextEditingController(text: variant.height?.toString() ?? ''));
        _variantPriceAdjControllers.add(TextEditingController(text: variant.priceAdjustment.toString()));
        _variantStockControllers.add(TextEditingController(text: variant.stockQuantity.toString()));
        _variantImageUrls.add(variant.imageUrl);
        _variantImageFiles.add(null);
        _variantColorHexs.add(variant.colorHex);
        _variantIsSwatch.add(variant.isSwatch);
      }
    }
  }

  Future<void> _pickMedia() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _mediaFiles.addAll(pickedFiles.map((file) => File(file.path)));
          _mediaThumbnails.addAll(List.generate(pickedFiles.length, (_) => null)); // No thumbnails for images
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick images: ${e.toString()}');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (pickedFile != null) {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: pickedFile.path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 120,
          quality: 75,
        );
        if (thumbnailPath == null) {
          _showErrorSnackBar('Failed to generate video thumbnail');
          return;
        }
        setState(() {
          _mediaFiles.add(File(pickedFile.path));
          _mediaThumbnails.add(thumbnailPath);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video or generate thumbnail: ${e.toString()}');
    }
  }

  Future<void> _pickVariantImage(int variantIndex) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _variantImageFiles[variantIndex] = File(pickedFile.path);
          _variantImageUrls[variantIndex] = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick variant image: ${e.toString()}');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      if (index < _mediaUrls.length) {
        _mediaUrlsToKeep.remove(_mediaUrls[index]);
        _mediaUrls.removeAt(index);
      } else {
        final fileIndex = index - _mediaUrls.length;
        _mediaFiles.removeAt(fileIndex);
        _mediaThumbnails.removeAt(fileIndex);
      }
    });
  }

  void _removeVariantImage(int variantIndex) {
    setState(() {
      _variantImageFiles[variantIndex] = null;
      _variantImageUrls[variantIndex] = null;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _addVariant() {
    setState(() {
      _variantNameControllers.add(TextEditingController());
      _variantWeightControllers.add(TextEditingController());
      _variantHeightControllers.add(TextEditingController());
      _variantPriceAdjControllers.add(TextEditingController(text: '0.0'));
      _variantStockControllers.add(TextEditingController(text: '0'));
      _variantImageFiles.add(null);
      _variantImageUrls.add(null);
      _variantColorHexs.add(null);
      _variantIsSwatch.add(false);
    });
  }

  void _pickColor(BuildContext context, int index) {
    Color pickerColor = _variantColorHexs[index] != null
        ? Color(int.parse('0xFF${_variantColorHexs[index]!}'))
        : Colors.white;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a Color', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
              paletteType: PaletteType.hueWheel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _variantColorHexs[index] = pickerColor.value.toRadixString(16).substring(2).toUpperCase();
                });
                Navigator.pop(context);
              },
              child: const Text('Select', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _removeVariant(int index) {
    setState(() {
      _variantNameControllers[index].dispose();
      _variantWeightControllers[index].dispose();
      _variantHeightControllers[index].dispose();
      _variantPriceAdjControllers[index].dispose();
      _variantStockControllers[index].dispose();

      _variantNameControllers.removeAt(index);
      _variantWeightControllers.removeAt(index);
      _variantHeightControllers.removeAt(index);
      _variantPriceAdjControllers.removeAt(index);
      _variantStockControllers.removeAt(index);
      _variantImageFiles.removeAt(index);
      _variantImageUrls.removeAt(index);
      _variantColorHexs.removeAt(index);
      _variantIsSwatch.removeAt(index);
    });
  }

  Widget _buildMediaPreview() {
    final allMedia = [
      ..._mediaUrls.map((m) => {'url': m.url, 'type': m.type, 'thumbnail': null}),
      ..._mediaFiles.asMap().entries.map((entry) {
        final index = entry.key;
        final file = entry.value;
        final isVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov');
        final thumbnailPath = index < _mediaThumbnails.length ? _mediaThumbnails[index] : null;
        return {
          'url': file.path,
          'type': isVideo ? 'video' : 'image',
          'thumbnail': thumbnailPath,
        };
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (allMedia.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allMedia.length,
              itemBuilder: (context, index) {
                final media = allMedia[index];
                final isVideo = media['type'] == 'video';
                final mediaPath = media['url']!;
                final thumbnailPath = media['thumbnail'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isVideo
                              ? thumbnailPath != null && File(thumbnailPath).existsSync()
                              ? Image.file(
                            File(thumbnailPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.videocam,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          )
                              : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.videocam,
                              size: 48,
                              color: Colors.grey,
                            ),
                          )
                              : mediaPath.startsWith('http')
                              ? Image.network(
                            mediaPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          )
                              : Image.file(
                            File(mediaPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      if (isVideo && thumbnailPath != null && File(thumbnailPath).existsSync())
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeMedia(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                'No media selected',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Add Images',
              onPressed: _pickMedia,
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.video_library,
              label: 'Add Video',
              onPressed: _pickVideo,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  Widget _buildVariantImagePicker(int index) {
    return Column(
      children: [
        if (_variantImageFiles[index] != null || _variantImageUrls[index] != null)
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _variantImageFiles[index] != null
                      ? Image.file(_variantImageFiles[index]!, fit: BoxFit.cover)
                      : Image.network(_variantImageUrls[index]!, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeVariantImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(Icons.image, color: Colors.grey, size: 40),
          ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.add_a_photo,
          label: 'Add Image',
          onPressed: () => _pickVariantImage(index),
        ),
      ],
    );
  }

  Widget _buildVariantColorPicker(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Show as color swatch', style: TextStyle(fontSize: 14)),
          value: _variantIsSwatch[index],
          onChanged: (value) {
            setState(() {
              _variantIsSwatch[index] = value ?? false;
            });
          },
          activeColor: Colors.blueAccent,
          dense: true,
        ),
        if (_variantIsSwatch[index])
          GestureDetector(
            onTap: () => _pickColor(context, index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _variantColorHexs[index] != null
                          ? Color(int.parse('0xFF${_variantColorHexs[index]!}'))
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _variantColorHexs[index] != null
                          ? '#${_variantColorHexs[index]}'
                          : 'Select a color',
                      style: TextStyle(color: _variantColorHexs[index] != null ? Colors.black87 : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantCard(int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _variantNameControllers[index],
                    label: 'Variant Name',
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _removeVariant(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVariantImagePicker(index),
                const SizedBox(width: 16),
                Expanded(child: _buildVariantColorPicker(index)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _variantWeightControllers[index],
                    label: 'Weight',
                    suffixText: 'kg',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _variantHeightControllers[index],
                    label: 'Height',
                    suffixText: 'cm',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _variantPriceAdjControllers[index],
                    label: 'Price Adjustment',
                    prefixText: currencySymbols[selectedCurrency],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value != null && double.tryParse(value) == null ? 'Invalid' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _variantStockControllers[index],
                    label: 'Stock',
                    keyboardType: TextInputType.number,
                    validator: (value) => value != null && int.tryParse(value) == null ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      List<ProductMedia> newMedia = [];
      _recentService.addRecentCategory(_categoryController.text.trim());
      if (_mediaFiles.isNotEmpty) {
        newMedia = await _productService.uploadMediaFiles(_mediaFiles, widget.existingProduct?.id ?? '');
      }

      final variants = <ProductVariant>[];
      for (int i = 0; i < _variantNameControllers.length; i++) {
        String? variantImageUrl;
        if (_variantImageFiles[i] != null) {
          final urls = await _productService.uploadMediaFiles([_variantImageFiles[i]!], '${widget.existingProduct?.id}_variant_$i');
          variantImageUrl = urls.first.url;
        }

        variants.add(
          ProductVariant(
            name: _variantNameControllers[i].text.trim(),
            weight: double.tryParse(_variantWeightControllers[i].text.trim()),
            height: double.tryParse(_variantHeightControllers[i].text.trim()),
            priceAdjustment: double.parse(_variantPriceAdjControllers[i].text.trim()),
            stockQuantity: int.parse(_variantStockControllers[i].text.trim()),
            imageUrl: variantImageUrl ?? _variantImageUrls[i],
            colorHex: _variantColorHexs[i],
            isSwatch: _variantIsSwatch[i],
          ),
        );
      }

      final product = Product(
        id: widget.existingProduct?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        basePrice: double.parse(_basePriceController.text.trim()),
        comparedAtPrice: _comparedAtPriceController.text.trim().isNotEmpty
            ? double.parse(_comparedAtPriceController.text.trim())
            : null,
        mediaUrls: [..._mediaUrlsToKeep, ...newMedia],
        category: _categoryController.text.trim(),
        variants: variants,
        userId: widget.userId,
        currency: selectedCurrency,
      );

      if (widget.existingProduct == null) {
        await _productService.addProduct(product, mediaFiles: _mediaFiles);
      } else {
        await _productService.updateProduct(product, newMediaFiles: _mediaFiles, mediaUrlsToKeep: _mediaUrlsToKeep);
      }

      widget.onProductSaved?.call();
      if (mounted) Navigator.of(context).pop(product);
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _comparedAtPriceController.dispose();
    _categoryController.dispose();
    for (var c in _variantNameControllers) {
      c.dispose();
    }
    for (var c in _variantWeightControllers) {
      c.dispose();
    }
    for (var c in _variantHeightControllers) {
      c.dispose();
    }
    for (var c in _variantPriceAdjControllers) {
      c.dispose();
    }
    for (var c in _variantStockControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.existingProduct == null ? 'Add Product' : 'Edit Product',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: Colors.blueAccent),
              onPressed: _saveForm,
              tooltip: 'Save Product',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMediaPreview(),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: 'Product Name',
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCurrency,
              decoration: InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => selectedCurrency = newValue);
                }
              },
              items: currencies.map<DropdownMenuItem<String>>((String code) {
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text('$code (${currencySymbols[code]})'),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _basePriceController,
              label: 'Base Price',
              prefixText: currencySymbols[selectedCurrency],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => value == null || double.tryParse(value) == null ? 'Invalid price' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _comparedAtPriceController,
              label: 'Compared At Price (for discounts)',
              prefixText: currencySymbols[selectedCurrency],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Invalid price' : null,
            ),
            const SizedBox(height: 16),
            _buildCategoryField(),
            const SizedBox(height: 24),
            const Text(
              'Variants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            ...List.generate(_variantNameControllers.length, (index) => _buildVariantCard(index)),
            const SizedBox(height: 12),
            Center(
              child: _buildActionButton(
                icon: Icons.add,
                label: 'Add Variant',
                onPressed: _addVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryField() {
    final recentService = RecentCategoryService.instance;
    final recentCats = recentService.recentCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _categoryController,
          onFieldSubmitted: (value) {
            recentService.addRecentCategory(value);
          },
          decoration: InputDecoration(
            labelText: 'Category',

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
              onSelected: (value) {
                _categoryController.text = value;
                recentService.addRecentCategory(value);
              },
              itemBuilder: (context) {
                final allOptions = [...recentCats, ..._allCategories.where((cat) => !recentCats.contains(cat))];
                return allOptions.map((category) {
                  return PopupMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        if (recentCats.contains(category))
                          const Icon(Icons.history, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Please select a category' : null,
        ),
        Obx(
              () => recentCats.isEmpty
              ? const SizedBox()
              : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentCats.length,
                itemBuilder: (context, index) {
                  final category = recentCats[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(category),
                      onPressed: () {
                        _categoryController.text = category;
                        recentService.addRecentCategory(category);
                      },
                      onDeleted: () {
                        recentService.removeRecentCategory(category);
                      },
                      avatar: const Icon(Icons.history, size: 16, color: Colors.grey),
                      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      backgroundColor: Colors.white,
                      selectedColor: Colors.blueAccent.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}