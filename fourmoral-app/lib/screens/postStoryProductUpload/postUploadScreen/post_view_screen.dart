import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/post_view_controller.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

class PostViewScreen extends StatelessWidget {
  final List<File> files;
  final ProfileModel? profileModel;

  const PostViewScreen({super.key, required this.files, this.profileModel});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      PostViewController(files: files, profileModel: profileModel),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: blue,
        title: const Text("Post View", style: TextStyle(color: Colors.black)),
        actions: [
          Obx(
            () =>
                controller.imageBytesList.isNotEmpty &&
                        controller.mediaTypes[controller.currentIndex.value] ==
                            'image'
                    ? _editButton(
                      "Edit Photo",
                      Icons.edit,
                      controller.openEditor,
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(
        () =>
            controller.imageBytesList.isEmpty
                ? Shimmer.fromColors(
                  baseColor: Colors.grey[400]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.grey[300],
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
                : PageView.builder(
                  key: UniqueKey(),
                  itemCount: controller.imageBytesList.length,
                  controller: PageController(
                    initialPage: controller.currentIndex.value,
                  ),
                  onPageChanged: controller.onPageChanged,
                  itemBuilder: (context, index) {
                    final type = controller.mediaTypes[index];
                    debugPrint("Rendering item at index $index, type: $type");
                    if (type == 'image') {
                      final bytes = controller.imageBytesList[index];
                      if (bytes == null || bytes.isEmpty) {
                        debugPrint("Image bytes null or empty at index $index");
                        return const Center(
                          child: Text(
                            "Unable to load image",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      try {
                        return Image.memory(bytes, fit: BoxFit.contain);
                      } catch (e) {
                        debugPrint("Error loading image at index $index: $e");
                        return const Center(
                          child: Text(
                            "Image format not supported",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                    } else {
                      return Obx(() {
                        if (controller.isVideoLoading.value) {
                          return Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              color: Colors.grey[300],
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          );
                        }
                        if (controller.videoError.value.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  controller.videoError.value,
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed:
                                      () => controller.retryVideoLoad(index),
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          );
                        }
                        if (controller.videoController.value == null ||
                            !controller
                                .videoController
                                .value!
                                .value
                                .isInitialized) {
                          debugPrint(
                            "Video controller not initialized at index $index",
                          );
                          return Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              color: Colors.grey[300],
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          );
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio:
                                  controller
                                      .videoController
                                      .value!
                                      .value
                                      .aspectRatio,
                              child: VideoPlayer(
                                controller.videoController.value!,
                              ),
                            ),
                            Obx(
                              () => AnimatedOpacity(
                                opacity: controller.isPlaying.value ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: GestureDetector(
                                  onTap: controller.toggleVideoPlayback,
                                  child: Icon(
                                    controller.isPlaying.value
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      });
                    }
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: blue,
        onPressed: controller.onNext,
        child: const Icon(
          Icons.arrow_right_alt_rounded,
          color: Colors.black,
          size: 30,
        ),
      ),
    );
  }

  Widget _editButton(String label, IconData icon, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Row(
            children: [
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }
}
