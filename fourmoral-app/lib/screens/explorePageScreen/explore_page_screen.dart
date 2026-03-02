import 'package:auto_size_text/auto_size_text.dart';
import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_controller.dart';
import 'package:fourmoral/screens/mapScreen/map_screen.dart';
import 'package:fourmoral/screens/postViewScreen/post_view_screen.dart';
import 'package:fourmoral/screens/searchScreen/search_screen.dart';
import 'package:get/get.dart';

import '../../constants/colors.dart';
import '../../models/post_model.dart';
import '../../widgets/box_decoration_widget.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../homePageScreen/home_page_widgets.dart';

class ExplorePageScreen extends StatelessWidget {
  final String? userPhoneNumber;
  final String? hashtag;

  const ExplorePageScreen({super.key, this.userPhoneNumber, this.hashtag});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ExploreCnt());
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    // Initialize hashtag filter if provided
    if (hashtag != null &&
        hashtag!.isNotEmpty &&
        controller.hashtagFilter.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setHashtagFilter(hashtag!);
      });
    }

    // Fetch data if not already fetched
    if (!controller.explorePageDataFetched.value) {
      controller.getExplorePageData();
    }

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: DoubleBackToCloseApp(
          snackBar: const SnackBar(content: Text('Double Press to Exit')),
          child: Obx(
            () =>
                controller.explorePageDataFetched.value
                    ? Container(
                      height: height,
                      width: width,
                      color: white,
                      child: Column(
                        children: [
                          Container(
                            height: height * 0.08,
                            width: width,
                            decoration: boxDecorationWidget(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      AutoSizeText(
                                        'Moral 1',

                                        style: TextStyle(
                                          color: black,
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 08,
                                            ),
                                            child: InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: const Text(
                                                          'Note',
                                                        ),
                                                        content: const Text(
                                                          'Only verified mentor, ngo , religious places account show here, and accounts you follow and contact.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                            child: const Text(
                                                              'Okay',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              },
                                              child: Center(
                                                child: Image.asset(
                                                  'assets/info.png',
                                                  height: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                          iconButton(
                                            context,
                                            width,
                                            () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        const SearchScreen(),
                                              ),
                                            ),
                                            Image.asset(
                                              'assets/search.png',
                                              width: 24,
                                              height: 24,
                                            ),
                                            0.08,
                                            null,
                                          ),
                                          const SizedBox(width: 10),
                                          iconButton(
                                            context,
                                            width,
                                            () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => MapScreen2(),
                                              ),
                                            ),
                                            Image.asset(
                                              'assets/earth.png',
                                              width: 24,
                                              height: 24,
                                            ),
                                            0.08,
                                            null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Obx(
                            () =>
                                controller.hashtagFilter.isNotEmpty
                                    ? _buildHashtagFilter(controller)
                                    : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: controller.pullRefresh,
                              color: Colors.blue,
                              backgroundColor: Colors.white,
                              child: Obx(() {
                                final displayList =
                                    controller.filteredPostDataList;
                                if (displayList.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.search_off,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          controller.hashtagFilter.isEmpty
                                              ? 'No posts available'
                                              : 'No posts found with ${controller.hashtagFilter.value}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return MasonryGridView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  gridDelegate:
                                      const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                      ),
                                  itemCount: displayList.length,
                                  itemBuilder: (context, index) {
                                    final postData = displayList[index];
                                    // Calculate height based on index or post data (e.g., random or metadata-driven)
                                    final height =
                                        index % 2 == 0
                                            ? 200.0
                                            : 300.0; // Example staggered heights
                                    return _buildPostItem(
                                      context,
                                      postData,
                                      height,
                                    );
                                  },
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    )
                    : buildCPIWidget(height, width),
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagFilter(ExploreCnt controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[200],
      child: Row(
        children: [
          Text(
            'Filter: ${controller.hashtagFilter.value}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.black54),
            onPressed: () {
              controller.clearHashtagFilter();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(
    BuildContext context,
    PostModel postData,
    double height,
  ) {
    String? imageUrl =
        postData.thumbnail.isNotEmpty
            ? postData.thumbnail.firstOrNull
            : postData.urls.firstOrNull;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostViewScreen(postId: postData.key),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: PostCard(
            image: imageUrl,
            isVideo:
                postData.mediaTypes.firstOrNull == "Video" ? "Video" : "image",
            height: height, // Pass height for staggered effect
          ),
        ),
      ),
    );
  }
}

// Modified PostCard widget to support custom height
class PostCard extends StatelessWidget {
  final String? image;
  final String isVideo;
  final double? height;

  const PostCard({
    super.key,
    required this.image,
    required this.isVideo,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        image:
            image != null
                ? DecorationImage(
                  image: NetworkImage(image!),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    debugPrint("Error loading image: $exception");
                  },
                )
                : null,
      ),
      child:
          isVideo == "Video"
              ? const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 40,
                ),
              )
              : null,
    );
  }
}
