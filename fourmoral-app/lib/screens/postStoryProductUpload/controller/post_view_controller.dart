import 'dart:io';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/postUploadScreen/add_post_screen.dart';
import 'package:get/get.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class PostViewController extends GetxController {
  final List<File> files;
  final ProfileModel? profileModel;
  final RxList<Uint8List?> imageBytesList = <Uint8List?>[].obs;
  final RxList<String> mediaTypes = <String>[].obs;
  final RxInt currentIndex = 0.obs;
  final Rx<VideoPlayerController?> videoController = Rx<VideoPlayerController?>(null);
  final RxBool isPlaying = false.obs;
  final RxBool isVideoLoading = false.obs;
  final RxString videoError = ''.obs;

  PostViewController({required this.files, this.profileModel});

  @override
  void onInit() {
    super.onInit();
    _loadAllImageBytes();
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= mediaTypes.length || mediaTypes[index] != 'video') return;
    isVideoLoading.value = true;
    videoError.value = '';
    try {
      await videoController.value?.dispose();
      videoController.value = VideoPlayerController.file(files[index]);
      await videoController.value!.initialize();
      videoController.value!.addListener(_onVideoPlayerStateChanged);
      isPlaying.value = false; // Reset playing state
      isVideoLoading.value = false;
      debugPrint("Video initialized successfully for index $index: ${files[index].path}");
      // Force UI update after initialization
      videoController.refresh();
    } catch (e) {
      debugPrint("Error initializing video at index $index: ${files[index].path}, error: $e");
      videoError.value = 'Failed to load video. Please try again.';
      isVideoLoading.value = false;
    }
  }

  void _onVideoPlayerStateChanged() {
    if (videoController.value != null) {
      isPlaying.value = videoController.value!.value.isPlaying;
      debugPrint("Video state changed: isPlaying=${isPlaying.value}, initialized=${videoController.value!.value.isInitialized}");
    }
  }

  Future<void> _loadAllImageBytes() async {
    List<Uint8List?> safeBytesList = [];
    List<String> mediaTypeList = [];

    for (File file in files) {
      try {
        final mime = lookupMimeType(file.path);
        if (mime != null && mime.startsWith('image/')) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            safeBytesList.add(bytes);
            mediaTypeList.add('image');
            debugPrint("Loaded image: ${file.path}");
          } else {
            debugPrint("Empty image bytes for: ${file.path}");
          }
        } else if (mime != null && mime.startsWith('video/')) {
          safeBytesList.add(null); // Use null for videos
          mediaTypeList.add('video');
          debugPrint("Loaded video: ${file.path}");
        } else {
          debugPrint("Unsupported file type: ${file.path}, MIME: $mime");
        }
      } catch (e) {
        debugPrint("Failed to read file: ${file.path}, error: $e");
      }
    }

    imageBytesList.assignAll(safeBytesList);
    mediaTypes.assignAll(mediaTypeList);

    if (mediaTypes.isNotEmpty && mediaTypes[0] == 'video') {
      await _initializeVideoController(0);
    }
  }

  Future<void> openEditor() async {
    if (mediaTypes[currentIndex.value] == 'image' && imageBytesList[currentIndex.value] != null) {
      final result = await Get.to(() => ImageEditor(image: imageBytesList[currentIndex.value]!));
      if (result != null && result is Uint8List) {
        imageBytesList[currentIndex.value] = result;
        debugPrint("Image edited successfully at index: ${currentIndex.value}");
      } else {
        debugPrint("No changes made in image editor");
      }
    }
  }

  Future<File> convertBytesToFile(Uint8List imageBytes, {String fileName = "image.jpg"}) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final file = File(filePath);
    return await file.writeAsBytes(imageBytes);
  }

  Future<void> onNext() async {
    final editedFiles = <File>[];

    for (int i = 0; i < files.length; i++) {
      if (mediaTypes[i] == 'image' && imageBytesList[i] != null) {
        final file = await convertBytesToFile(imageBytesList[i]!);

        editedFiles.add(file);
      } else {
        editedFiles.add(files[i]); // Original video
      }
    }

    Get.to(() => AddPostTextScreen(files: editedFiles, profileModel: profileModel));
  }

  void onPageChanged(int index) {
    currentIndex.value = index;
    isPlaying.value = false;
    isVideoLoading.value = false;
    videoError.value = '';
    if (mediaTypes[index] == 'video') {
      _initializeVideoController(index);
    }
  }

  void toggleVideoPlayback() {
    if (videoController.value != null && !isVideoLoading.value && videoError.value.isEmpty) {
      if (videoController.value!.value.isPlaying) {
        videoController.value!.pause();
      } else {
        videoController.value!.play();
      }
      isPlaying.value = videoController.value!.value.isPlaying;
      debugPrint("Toggled video playback: isPlaying=${isPlaying.value}");
    }
  }

  void retryVideoLoad(int index) {
    debugPrint("Retrying video load for index $index");
    _initializeVideoController(index);
  }

  @override
  void onClose() {
    videoController.value?.removeListener(_onVideoPlayerStateChanged);
    videoController.value?.dispose();
    super.onClose();
  }
}
