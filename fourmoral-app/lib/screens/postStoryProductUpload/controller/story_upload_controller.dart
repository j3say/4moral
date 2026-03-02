import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/camera_services.dart';
import 'package:fourmoral/screens/postStoryProductUpload/storyUploadScreen/story_preview_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/widget/gallery_view.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

class StoryUploadController extends GetxController {
  final CameraService cameraService;
  final RxBool isRecording = false.obs;
  final RxString? capturedFilePath = RxString("");
  final RxString? thumbnailPath = RxString("");

  StoryUploadController({required this.cameraService});

  Future<void> capturePhoto(BuildContext context) async {
    try {
      if (cameraService.isInitialized &&
          cameraService.controller != null &&
          !isRecording.value) {
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final XFile photo = await cameraService.controller!.takePicture();
        await photo.saveTo(filePath);
        capturedFilePath?.value = filePath;
        thumbnailPath?.value = "";
        _navigateToPreviewScreen(context);
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  Future<void> startVideoRecording(BuildContext context) async {
    try {
      if (cameraService.isInitialized &&
          cameraService.controller != null &&
          !cameraService.controller!.value.isRecordingVideo) {
        await cameraService.controller!.startVideoRecording();
        isRecording.value = true;
      }
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start video recording: $e')),
        );
      }
    }
  }

  Future<void> stopVideoRecording(BuildContext context) async {
    try {
      if (cameraService.isInitialized &&
          cameraService.controller != null &&
          cameraService.controller!.value.isRecordingVideo) {
        final XFile video =
            await cameraService.controller!.stopVideoRecording();
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

        final String? thumbnailFile = await video_thumbnail
            .VideoThumbnail.thumbnailFile(
          video: filePath,
          thumbnailPath: thumbnailPath,
          imageFormat: video_thumbnail.ImageFormat.JPEG,
          maxWidth: 320,
          quality: 75,
        );

        isRecording.value = false;
        capturedFilePath?.value = filePath;
        this.thumbnailPath?.value = thumbnailFile ?? "";
        _navigateToPreviewScreen(context);
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (context.mounted) {
        isRecording.value = false; // Ensure recording state is reset on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop video recording: $e')),
        );
      }
    }
  }

  void _navigateToPreviewScreen(BuildContext context) {
    if (capturedFilePath?.value != null && context.mounted) {
      Get.to(
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 500),
        () => StoryPreviewScreen(
          filePath: capturedFilePath?.value ?? "",
          thumbnailPath: thumbnailPath?.value,
        ),
      )?.then((value) {
        capturedFilePath?.value = "";
        thumbnailPath?.value = "";
      });
    }
  }

  Future<void> openGallery(BuildContext context) async {
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

    if (context.mounted) {
      await showModalBottomSheet<void>(
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
                  (context, scrollController) => _GalleryBottomSheet(
                    albums: albums,
                    onMediaSelected: (filePath, thumbnailPath, index) {
                      capturedFilePath?.value = filePath;
                      this.thumbnailPath?.value = thumbnailPath ?? "";
                      Navigator.pop(context);
                      _navigateToPreviewScreen(context);
                    },
                  ),
            ),
      );
    }
  }

  void handleButtonTap(BuildContext context) {
    if (isRecording.value) {
      stopVideoRecording(context);
    } else {
      capturePhoto(context);
    }
  }
}

class _GalleryBottomSheet extends StatefulWidget {
  final List<AssetPathEntity> albums;
  final void Function(String filePath, String? thumbnailPath, int? index)
  onMediaSelected;

  const _GalleryBottomSheet({
    required this.albums,
    required this.onMediaSelected,
  });

  @override
  State<_GalleryBottomSheet> createState() => _GalleryBottomSheetState();
}

class _GalleryBottomSheetState extends State<_GalleryBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _galleryTabController;

  @override
  void initState() {
    super.initState();
    _galleryTabController = TabController(length: 4, vsync: this);
  }

  Future<void> _openAlbumPhotosSheet(
    BuildContext context,
    AssetPathEntity album,
  ) async {
    if (context.mounted) {
      await showModalBottomSheet<void>(
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
                          onMediaSelected: (filePath, thumbnailPath, index) {
                            widget.onMediaSelected(
                              filePath,
                              thumbnailPath,
                              index,
                            );
                            Navigator.pop(context);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
            ),
      );
    }
  }

  @override
  void dispose() {
    _galleryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                onMediaSelected: widget.onMediaSelected,
              ),
              GalleryView(
                type: RequestType.video,
                onMediaSelected: widget.onMediaSelected,
              ),
              GalleryView(
                type: RequestType.all,
                onMediaSelected: widget.onMediaSelected,
              ),
              GridView.builder(
                controller: ScrollController(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: widget.albums.length,
                itemBuilder: (context, index) {
                  final album = widget.albums[index];
                  return GestureDetector(
                    onTap: () => _openAlbumPhotosSheet(context, album),
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
                                    snapshot.hasData && snapshot.data != null
                                        ? Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        )
                                        : const Center(
                                          child: CircularProgressIndicator(),
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
    );
  }
}
