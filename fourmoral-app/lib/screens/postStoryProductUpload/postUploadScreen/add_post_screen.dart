import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/add_post_controller.dart';
import 'package:fourmoral/screens/postStoryProductUpload/postUploadScreen/contact_selection_screen.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

class AddPostTextScreen extends StatefulWidget {
  final List<File> files;
  final ProfileModel? profileModel;

  const AddPostTextScreen({super.key, required this.files, this.profileModel});

  @override
  State<AddPostTextScreen> createState() => _AddPostTextScreenState();
}

class _AddPostTextScreenState extends State<AddPostTextScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AddPostTextController(files: widget.files, profileModel: widget.profileModel),
    );
    final screenSize = MediaQuery.of(context).size;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: blue,
            elevation: 0,
            title: const Text(
              'New Post',
              style: TextStyle(color: Colors.black),
            ),
            centerTitle: false,
          ),
          floatingActionButton: Obx(
            () => FloatingActionButton(
              backgroundColor: controller.uploading.value ? Colors.grey : blue,
              onPressed:
                  controller.uploading.value
                      ? null
                      : () => controller.uploadPost(context),
              child: const Icon(
                Icons.arrow_right_alt_rounded,
                color: Colors.black,
                size: 30,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      height: screenSize.height * 0.7,
                      width: double.infinity,
                      child: Obx(
                        () =>
                            controller.imageBytesList.isEmpty
                                ? Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    color: Colors.grey[300],
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                                : PageView.builder(
                                  key: UniqueKey(),
                                  physics: BouncingScrollPhysics(),
                                  itemCount: controller.imageBytesList.length,
                                  controller: PageController(
                                    initialPage: controller.currentIndex.value,
                                  ),
                                  onPageChanged: controller.onPageChanged,
                                  itemBuilder: (context, index) {
                                    final type = controller.mediaTypes[index];
                                    if (type == 'image') {
                                      final bytes =
                                          controller.imageBytesList[index];

                                      try {
                                        return Image.memory(
                                          bytes,
                                          fit: BoxFit.contain,
                                          width: screenSize.width,
                                          height: screenSize.height * 0.6,
                                        );
                                      } catch (e) {
                                        return const Center(
                                          child: Text(
                                            "Image format not supported",
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
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

                                        if (controller.videoController.value ==
                                                null ||
                                            !controller
                                                .videoController
                                                .value!
                                                .value
                                                .isInitialized) {
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
                                                controller
                                                    .videoController
                                                    .value!,
                                              ),
                                            ),
                                            Obx(
                                              () => AnimatedOpacity(
                                                opacity:
                                                    controller.isPlaying.value
                                                        ? 0.0
                                                        : 1.0,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: GestureDetector(
                                                  onTap:
                                                      controller
                                                          .toggleVideoPlayback,
                                                  child: Icon(
                                                    controller.isPlaying.value
                                                        ? Icons
                                                            .pause_circle_filled
                                                        : Icons
                                                            .play_circle_filled,
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
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Obx(
                        () => Text(
                          "${controller.currentIndex.value + 1} / ${controller.files.length}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.black,
                      ),
                      title:
                          controller.isLocationLoading.value
                              ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(),
                                ),
                              )
                              : Text(
                                controller.location.value.text.isEmpty
                                    ? "Add location"
                                    : controller.location.value.text,
                                style: const TextStyle(color: Colors.black),
                              ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.black,
                      ),
                      onTap:
                          controller.isLocationLoading.value
                              ? null
                              : () => controller.pickLocation(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 0),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller.caption,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Write a caption...",
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Share Options",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Obx(
                    () => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Share with Contacts"),
                      value: controller.shareWithContacts.value,
                      onChanged: (value) {
                        if (value != null) {
                          controller.shareWithContacts.value = value;
                        }
                      },
                    ),
                  ),
                  if (controller.profileController.contactAccount.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.people, color: Colors.black),
                      title: const Text("Select Contact"),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.black,
                      ),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ContactSelectionScreen(
                                    profileModel: widget.profileModel,
                                    contactsController:
                                        controller.contactsScreenCnt,
                                    profileController:
                                        controller.profileController,
                                  ),
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
