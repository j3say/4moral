import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/productUploadScreen/product_preview_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/camera_services.dart';
import 'package:fourmoral/screens/postStoryProductUpload/widget/gallery_view.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

class ProductUploadScreen extends StatefulWidget {
  final ProfileModel? profileModel;
  final CameraService cameraService;

  const ProductUploadScreen({
    super.key,
    this.profileModel,
    required this.cameraService,
  });

  @override
  State<ProductUploadScreen> createState() => _ProductUploadScreenState();
}

class _ProductUploadScreenState extends State<ProductUploadScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isRecording = false;
  List<Map<String, String?>> _selectedMedia = [];
  late TabController _galleryTabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _galleryTabController = TabController(length: 4, vsync: this);
  }

  Future<void> _capturePhoto() async {
    try {
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          !_isRecording) {
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final XFile photo =
            await widget.cameraService.controller!.takePicture();
        await photo.saveTo(filePath);
        if (mounted) {
          setState(() {
            _selectedMedia = [
              {'filePath': filePath, 'thumbnailPath': null},
            ];
          });
          _navigateToPreviewScreen(context);
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  Future<void> _startVideoRecording() async {
    try {
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          !widget.cameraService.controller!.value.isRecordingVideo) {
        await widget.cameraService.controller!.startVideoRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start video recording: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    try {
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          widget.cameraService.controller!.value.isRecordingVideo) {
        final XFile video =
            await widget.cameraService.controller!.stopVideoRecording();
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        final thumbnailPath = path.join(
          tempDir.path,
          'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await video.saveTo(filePath);

        final thumbnailFile = await video_thumbnail
            .VideoThumbnail.thumbnailFile(
          video: filePath,
          thumbnailPath: thumbnailPath,
          imageFormat: video_thumbnail.ImageFormat.JPEG,
          maxWidth: 320,
          quality: 75,
        );

        if (mounted) {
          setState(() {
            _isRecording = false;
            _selectedMedia = [
              {'filePath': filePath, 'thumbnailPath': thumbnailFile},
            ];
          });
          _navigateToPreviewScreen(context);
        }
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop video recording: $e')),
        );
      }
    }
  }

  void _navigateToPreviewScreen(BuildContext context) {
    if (_selectedMedia.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProductPreviewScreen(
                selectedMedia: _selectedMedia,
                profileModel: widget.profileModel,
              ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedMedia.clear();
          });
        }
      });
    }
  }

  Future<void> _openGallery() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      Get.snackbar('Permission Denied', 'Please grant access to photos');
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.all,
    );
    if (albums.isEmpty) {
      Get.snackbar('No Albums', 'No albums available');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => Column(
                  children: [
                    Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: TabBar(
                        controller: _galleryTabController,
                        indicatorColor: Colors.blue,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'Recent'),
                          Tab(text: 'Video'),
                          Tab(text: 'All'),
                          Tab(text: 'All Albums'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _galleryTabController,
                        children: [
                          GalleryView(
                            type: RequestType.all,
                            isMultipleSelection: true,
                            onMediaSelected: (filePath, thumbnailPath, index) {
                              // Not used for multiple selection
                            },
                            onSelectionComplete: (selectedItems) {
                              if (mounted) {
                                setState(() {
                                  _selectedMedia = selectedItems;
                                });
                                Navigator.pop(context);
                                _navigateToPreviewScreen(context);
                              }
                            },
                          ),
                          GalleryView(
                            type: RequestType.video,
                            isMultipleSelection: true,
                            onMediaSelected: (filePath, thumbnailPath, index) {
                              // Not used for multiple selection
                            },
                            onSelectionComplete: (selectedItems) {
                              if (mounted) {
                                setState(() {
                                  _selectedMedia = selectedItems;
                                });
                                Navigator.pop(context);
                                _navigateToPreviewScreen(context);
                              }
                            },
                          ),
                          GalleryView(
                            type: RequestType.all,
                            isMultipleSelection: true,
                            onMediaSelected: (filePath, thumbnailPath, index) {
                              // Not used for multiple selection
                            },
                            onSelectionComplete: (selectedItems) {
                              if (mounted) {
                                setState(() {
                                  _selectedMedia = selectedItems;
                                });
                                Navigator.pop(context);
                                _navigateToPreviewScreen(context);
                              }
                            },
                          ),
                          GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              return GestureDetector(
                                onTap: () => _openAlbumPhotosSheet(album),
                                child: FutureBuilder<Uint8List?>(
                                  future: album
                                      .getAssetListRange(start: 0, end: 1)
                                      .then(
                                        (list) =>
                                            list.isNotEmpty
                                                ? list[0].thumbnailDataWithSize(
                                                  const ThumbnailSize(200, 200),
                                                )
                                                : null,
                                      ),
                                  builder: (context, snapshot) {
                                    return Card(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child:
                                                snapshot.hasData &&
                                                        snapshot.data != null
                                                    ? Image.memory(
                                                      snapshot.data!,
                                                      fit: BoxFit.cover,
                                                    )
                                                    : const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Text(
                                              album.name,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _openAlbumPhotosSheet(AssetPathEntity album) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        album.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GalleryView(
                        type: RequestType.all,
                        album: album,
                        isMultipleSelection: true,
                        onMediaSelected: (filePath, thumbnailPath, index) {
                          // Not used for multiple selection
                        },
                        onSelectionComplete: (selectedItems) {
                          if (mounted) {
                            setState(() {
                              _selectedMedia = selectedItems;
                            });
                            Navigator.pop(context);
                            Navigator.pop(context);
                            Navigator.pop(context);
                            _navigateToPreviewScreen(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _handleButtonTap() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _capturePhoto();
    }
  }

  @override
  void dispose() {
    _galleryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.cameraService.isInitialized &&
                widget.cameraService.controller != null
            ? Positioned.fill(
              child: AspectRatio(
                aspectRatio: widget.cameraService.controller!.value.aspectRatio,
                child: CameraPreview(widget.cameraService.controller!),
              ),
            )
            : const Center(
              child: Text(
                'No camera available.',
                style: TextStyle(color: Colors.white),
              ),
            ),
        if (_isRecording)
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red,
              child: const Text(
                'Recording',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        Positioned(
          bottom: 60,
          left: 20,
          child: IconButton(
            icon: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 30,
            ),
            onPressed: _openGallery,
          ),
        ),
        Positioned(
          bottom: 60,
          child: GestureDetector(
            onTap: _handleButtonTap,
            onLongPress: _startVideoRecording,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.grey.shade300,
                  width: _isRecording ? 4.0 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  _isRecording
                      ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                      : const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }
}
