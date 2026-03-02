import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class StoryPreviewController extends GetxController {
  final String filePath;
  final String? thumbnailPath;
  final Story2Controller storyController = Get.find<Story2Controller>();
  final TextEditingController captionController = TextEditingController();
  final Rx<VideoPlayerController?> videoController = Rx<VideoPlayerController?>(null);
  final RxBool isVideoInitialized = false.obs;
  final RxBool isPlaying = false.obs;

  StoryPreviewController({required this.filePath, this.thumbnailPath});

  @override
  void onInit() {
    super.onInit();
    storyController.initializeUserData();
    if (filePath.endsWith('.mp4')) {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final controller = VideoPlayerController.file(File(filePath));
      videoController.value = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      isVideoInitialized.value = true;
      isPlaying.value = true;
      update(); // Ensure GetBuilder updates
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      isVideoInitialized.value = false;
      isPlaying.value = false;
      update(); // Update UI to show thumbnail or error
    }
  }

  void toggleVideoPlayback() {
    final controller = videoController.value;
    if (controller != null && isVideoInitialized.value) {
      if (controller.value.isPlaying) {
        controller.pause();
        isPlaying.value = false;
      } else {
        controller.play();
        isPlaying.value = true;
      }
      update(); // Ensure GetBuilder updates
    }
  }

  Future<void> uploadStory(BuildContext context) async {
    final file = File(filePath);
    final thumbnailFile = thumbnailPath != null ? File(thumbnailPath!) : null;
    final caption = captionController.text;
    final type = filePath.endsWith('.mp4') ? StoryType.video : StoryType.image;
    await storyController.uploadStory(
      file,
      type,
      caption: caption,
      thumbnailFile: thumbnailFile,
    );
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void onClose() {
    videoController.value?.dispose();
    captionController.dispose();
    super.onClose();
  }
}