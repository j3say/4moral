import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/story_upload_controller.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/camera_services.dart';
import 'package:get/get.dart';

class StoryUploadScreen extends StatelessWidget {
  final CameraService cameraService;

  const StoryUploadScreen({super.key, required this.cameraService});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StoryUploadController(cameraService: cameraService));

    return Stack(
      alignment: Alignment.center,
      children: [
        controller.cameraService.isInitialized && controller.cameraService.controller != null
            ? Positioned.fill(
          child: AspectRatio(
            aspectRatio: controller.cameraService.controller!.value.aspectRatio,
            child: CameraPreview(controller.cameraService.controller!),
          ),
        )
            : const Center(
          child: Text(
            'No camera available.',
            style: TextStyle(color: Colors.white),
          ),
        ),
        Obx(
              () => controller.isRecording.value
              ? Positioned(
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
          )
              : const SizedBox.shrink(),
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
            onPressed: () => controller.openGallery(context),
          ),
        ),
        Obx(
              () => Positioned(
            bottom: 60,
            child: GestureDetector(
              onTap: () => controller.handleButtonTap(context),
              onLongPress: () => controller.startVideoRecording(context),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: controller.isRecording.value ? Colors.red : Colors.grey.shade300,
                    width: controller.isRecording.value ? 4.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: controller.isRecording.value
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
        ),
      ],
    );
  }
}