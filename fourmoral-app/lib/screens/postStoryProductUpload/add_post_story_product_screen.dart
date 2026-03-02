import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/add_post_story_product_controller.dart';
import 'package:fourmoral/screens/postStoryProductUpload/postUploadScreen/post_upload_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/productUploadScreen/product_upload_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/storyUploadScreen/story_upload_screen.dart';
import 'package:get/get.dart';

class AddPostStoryProductScreen extends StatefulWidget {
  const AddPostStoryProductScreen({super.key, this.profileModel});

  final ProfileModel? profileModel;

  @override
  State<AddPostStoryProductScreen> createState() =>
      _AddPostStoryProductScreenState();
}

class _AddPostStoryProductScreenState extends State<AddPostStoryProductScreen>
    with SingleTickerProviderStateMixin {
  late final AddPostStoryProductController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(AddPostStoryProductController(widget.profileModel));
    _controller.initialize(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        title: Obx(
          () => Text(
            _controller.appBarTitle.value,
            style: const TextStyle(color: Colors.black),
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Obx(
            () =>
                _controller.isCameraLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.isCameraPermissionDenied.value
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Camera permission denied.\nTap to grant permission.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed:
                                () => _controller.requestCameraPermission(
                                  context,
                                ),
                            child: const Text('Grant Permission'),
                          ),
                        ],
                      ),
                    )
                    : TabBarView(
                      controller: _controller.tabController,
                      children: [
                        PostUploadScreen(
                          profileModel: widget.profileModel,
                          cameraService: _controller.cameraService,
                        ),
                        StoryUploadScreen(
                          cameraService: _controller.cameraService,
                        ),
                        if (_controller.isBusinessAccount)
                          ProductUploadScreen(
                            profileModel: widget.profileModel,
                            cameraService: _controller.cameraService,
                          ),
                      ],
                    ),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: blue.withOpacity(0.2),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: TabBar(
              controller: _controller.tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: blue,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              tabs: [
                const TabItem(title: 'POST'),
                const TabItem(title: 'STORY'),
                if (_controller.isBusinessAccount)
                  const TabItem(title: 'PRODUCT'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TabItem extends StatelessWidget {
  final String title;

  const TabItem({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
