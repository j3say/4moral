import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/product/product_edit.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ProductPreviewScreen extends StatefulWidget {
  final List<Map<String, String?>>? selectedMedia;
  final ProfileModel? profileModel;

  const ProductPreviewScreen({
    super.key,

    this.selectedMedia,
    this.profileModel,
  });

  @override
  State<ProductPreviewScreen> createState() => _ProductPreviewScreenState();
}

class _ProductPreviewScreenState extends State<ProductPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  int _currentMediaIndex = 0;
  List<Map<String, String?>> _mediaItems = [];

  @override
  void initState() {
    super.initState();

    if (widget.selectedMedia != null && widget.selectedMedia!.isNotEmpty) {
      _mediaItems = widget.selectedMedia!;
    }
    if (_mediaItems.isNotEmpty &&
        _mediaItems[0]['filePath']!.endsWith('.mp4')) {
      _initializeVideoPlayer(_mediaItems[0]['filePath']!);
    }
  }

  Future<void> _initializeVideoPlayer(String filePath) async {
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(filePath));
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview'), backgroundColor: blue),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(
                child:
                    _mediaItems.isNotEmpty
                        ? CarouselSlider.builder(
                          itemCount: _mediaItems.length,
                          itemBuilder: (context, index, realIndex) {
                            final media = _mediaItems[index];
                            final isVideo = media['filePath']!.endsWith('.mp4');
                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                  maxHeight: constraints.maxHeight * 0.8,
                                ),
                                child:
                                    isVideo
                                        ? _isVideoInitialized &&
                                                _videoController != null &&
                                                index == _currentMediaIndex
                                            ? AspectRatio(
                                              aspectRatio:
                                                  _videoController!
                                                      .value
                                                      .aspectRatio,
                                              child: VideoPlayer(
                                                _videoController!,
                                              ),
                                            )
                                            : Image.file(
                                              File(
                                                media['thumbnailPath'] ??
                                                    media['filePath']!,
                                              ),
                                              fit: BoxFit.contain,
                                              height: Get.height,
                                              width: Get.width,
                                            )
                                        : Image.file(
                                          File(media['filePath']!),
                                          fit: BoxFit.contain,
                                          height: Get.height,
                                          width: Get.width,
                                        ),
                              ),
                            );
                          },
                          options: CarouselOptions(
                            height: Get.height,
                            aspectRatio: 1.0,
                            enlargeCenterPage: true,
                            viewportFraction: 1.0,
                            enableInfiniteScroll: false,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentMediaIndex = index;
                                _isVideoInitialized = false;
                              });
                              if (_mediaItems[index]['filePath']!.endsWith(
                                '.mp4',
                              )) {
                                _initializeVideoPlayer(
                                  _mediaItems[index]['filePath']!,
                                );
                              } else {
                                _videoController?.dispose();
                                _videoController = null;
                                setState(() {
                                  _isVideoInitialized = false;
                                });
                              }
                            },
                          ),
                        )
                        : const Center(child: Text('No media selected')),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ProductEditPage(userId: widget.profileModel?.uId ?? "",selectedMedia: widget.selectedMedia,),
            ),
          );
        },
        child: const Icon(Icons.send),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    // _captionController.dispose();
    super.dispose();
  }
}
