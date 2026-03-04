import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/edit_post_controller.dart';
import 'package:get/get.dart';

class EditPostScreen extends StatelessWidget {
  final PostModel post;
  final ProfileModel profile;
  final DocumentReference postReference;

  const EditPostScreen({
    super.key,
    required this.post,
    required this.profile,
    required this.postReference,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      EditPostController(
        post: post,
        profile: profile,
        postReference: postReference,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Post"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: controller.updatePost,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Media preview (read-only)
            if (post.urls.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  post.mediaTypes[0].toLowerCase() == 'video'
                      ? post.thumbnail.isNotEmpty
                          ? post.thumbnail[0]
                          : post.urls[0]
                      : post.urls[0],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("Error loading media: $error");
                    return const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 40),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Caption field with hashtag/mention support
            TextFormField(
              controller: controller.captionController,
              focusNode: controller.captionFocusNode,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Use # for hashtags or @ for mentions',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => controller.caption.value = value,
            ),

            const SizedBox(height: 20),

            // Location toggle
            Obx(
              () => SwitchListTile(
                title: const Text("Include Location"),
                value: controller.includeLocation.value,
                onChanged: (value) async {
                  if (value) {
                    await controller.getUserLocation();
                  } else {
                    controller.includeLocation.value = false;
                    controller.locationString.value = "";
                    debugPrint("Location disabled");
                  }
                },
              ),
            ),

            Obx(
              () =>
                  controller.includeLocation.value &&
                          controller.locationString.value.isNotEmpty
                      ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Location: ${controller.locationString.value}",
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
