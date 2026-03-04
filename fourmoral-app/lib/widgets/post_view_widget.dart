import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/catalog_model.dart';
import 'package:fourmoral/screens/askScreen/ask_screen.dart';
import 'package:fourmoral/screens/catalog/catalog_repository.dart';
import 'package:fourmoral/screens/mentorAskScreen/mentor_ask_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/postUploadScreen/edit_post_screen.dart';
import 'package:fourmoral/screens/profileScreen/badge_widget.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/services/set_or_remove_like.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:fourmoral/widgets/profile_image_widget.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../constants/colors.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart';
import '../screens/commentScreen/comment_screen.dart';
import '../screens/homePageScreen/home_page_widgets.dart';
import '../screens/otherProfileScreen/other_profile_screen.dart';
import '../screens/videoScreen/video_screen.dart';

class PostViewWidget extends StatefulWidget {
  final PostModel postDataObject;
  final bool isCurrentUser;

  const PostViewWidget({
    super.key,
    required this.postDataObject,
    required this.isCurrentUser,
  });

  @override
  State<PostViewWidget> createState() => _PostViewWidgetState();
}

class _PostViewWidgetState extends State<PostViewWidget>
    with SingleTickerProviderStateMixin {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int current = 0;
  List<Widget> _carouselItems = [];
  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');
  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');
  AnimationController? _heartAnimationController;
  Animation<double>? _heartScaleAnimation;
  Animation<double>? _heartOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Register ProfileCnt before using GetBuilder
    Get.put(ProfileController());
    _generateCarouselItems();
    // Initialize animation controller for heart effect
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _heartScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _heartAnimationController!,
        curve: Curves.easeOut,
      ),
    );
    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartAnimationController!, curve: Curves.easeIn),
    );
    _heartAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _heartAnimationController!.reset();
      }
    });
  }

  @override
  void dispose() {
    _heartAnimationController?.dispose();
    super.dispose();
  }

  bool isVideoAtIndex(int index) {
    if (index < widget.postDataObject.mediaTypes.length) {
      return widget.postDataObject.mediaTypes[index].toLowerCase() == 'video';
    }
    return false;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _triggerHeartAnimation() {
    _heartAnimationController!.forward();
  }

  void _generateCarouselItems() {
    _carouselItems =
        widget.postDataObject.urls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          final isVideo = isVideoAtIndex(index);
          final zoomController = TransformationController();
          VideoPlayerController? videoController;

          return StatefulBuilder(
            builder: (context, setState) {
              final mediaUrl =
                  isVideo
                      ? (widget.postDataObject.thumbnail.isNotEmpty
                          ? widget.postDataObject.thumbnail
                          : url)
                      : url;

              if (isVideo && videoController == null) {
                videoController = VideoPlayerController.networkUrl(
                    Uri.parse(url),
                  )
                  ..initialize().then((_) {
                    videoController!.setLooping(true);
                    videoController!.play();
                    if (mounted) setState(() {});
                  });
              }

              final imageWithZoom = InteractiveViewer(
                transformationController: zoomController,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: mediaUrl.toString(),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder:
                      (context, url) => const Image(
                        image: AssetImage("assets/photoPlaceholder.png"),
                        fit: BoxFit.contain,
                      ),
                  errorWidget:
                      (context, url, error) => const Image(
                        image: AssetImage("assets/photoPlaceholder.png"),
                        fit: BoxFit.contain,
                      ),
                ),
              );

              return InkWell(
                onTap:
                    isVideo
                        ? () => Get.to(() => VideoPlayerScreen(videoLink: url))
                        : null,
                onDoubleTap: () {
                  if (!Get.find<ProfileController>().likeLoading) {
                    setOrRemoveLike(
                      widget.postDataObject,
                      profileDataModel!,
                      collectionPostReference,
                      collectionUserReference,
                      setState,
                    );
                    _triggerHeartAnimation();
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    isVideo
                        ? videoController != null &&
                                videoController!.value.isInitialized
                            ? Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio:
                                      videoController!.value.aspectRatio,
                                  child: VideoPlayer(videoController!),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatDuration(
                                        videoController!.value.duration,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : const Center(child: CircularProgressIndicator())
                        : imageWithZoom,
                    ScaleTransition(
                      scale: _heartScaleAnimation!,
                      child: FadeTransition(
                        opacity: _heartOpacityAnimation!,
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 100,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList();
  }

  void showDeleteConfirmation(
    BuildContext context,
    PostModel post,
    CollectionReference postsRef,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => ConfirmDialogueBox(
            title: "Delete Post",
            content: "Are you sure you want to delete this post?",
            onConfirm: () async {
              await deletePost(post, postsRef, context);
            },
            onCancel: () => Navigator.pop(context),
          ),
    );
  }

  Future<DocumentReference?> getPostReference(String postKey) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('Posts')
              .where('key', isEqualTo: postKey)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.reference;
    } catch (e) {
      debugPrint('Error finding post: $e');
      return null;
    }
  }

  void _navigateToEditScreen(
    BuildContext context,
    PostModel post,
    ProfileModel profile,
  ) async {
    final postRef = await getPostReference(post.key);

    if (postRef == null) {
      flutterShowToast("Post not found");
      return;
    }

    Get.to(
      () =>
          EditPostScreen(post: post, postReference: postRef, profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1.0)),
      ),
      padding: const EdgeInsets.only(bottom: 10.0, right: 20, left: 20),
      margin: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.postDataObject.mobileNumber !=
                      profileDataModel?.mobileNumber) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => OtherProfileScreen(
                              mobileNumber: widget.postDataObject.mobileNumber,
                              currentUsername: profileDataModel?.username,
                            ),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    profileScreenImageWidget(
                      Get.height,
                      Get.width,
                      widget.postDataObject.profilePicture,
                      0.03,
                    ),
                    const SizedBox(width: 10),
                    AutoSizeText(
                      widget.postDataObject.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              BadgeWidget(badge: widget.postDataObject.actype),
            ],
          ),
          SizedBox(height: Get.height * 0.01),
          Column(
            children: [
              CarouselSlider(
                carouselController: _carouselController,
                options: CarouselOptions(
                  height: Get.height * 0.5,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: widget.postDataObject.urls.length > 1,
                  autoPlay: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      current = index;
                    });
                  },
                ),
                items: _carouselItems,
              ),
              SizedBox(height: 8),
              if (widget.postDataObject.urls.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.postDataObject.urls.length, (
                    index,
                  ) {
                    return GestureDetector(
                      onTap: () {
                        _carouselController.animateToPage(index);
                        setState(() {
                          current = index;
                        });
                      },
                      child: Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              current == index
                                  ? Colors.black
                                  : Colors.black.withOpacity(0.4),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
          SizedBox(height: Get.height * 0.01),
          Align(
            alignment: Alignment.centerLeft,
            child: AutoSizeText(
              widget.postDataObject.caption,
              style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            ),
          ),
          SizedBox(height: Get.height * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  widget.postDataObject.mobileNumber !=
                          profileDataModel?.mobileNumber
                      ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        onPressed: () {
                          followOrRemoveMentor(
                            widget.postDataObject,
                            profileDataModel!,
                            collectionUserReference,
                            setState,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profileDataModel?.followMentors.contains(
                                        widget.postDataObject.mobileNumber,
                                      ) ==
                                      false
                                  ? 'Follow'
                                  : 'Unfollow',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Container(width: 0),
                  SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                    onPressed: () {
                      if (widget.postDataObject.mobileNumber ==
                          profileDataModel?.mobileNumber) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => MentorAskScreen(
                                  postObject: widget.postDataObject,
                                ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AskScreen(
                                  postObject: widget.postDataObject,
                                  phone: profileDataModel?.mobileNumber,
                                ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Ask',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  GetBuilder<ProfileController>(
                    builder: (cnt) {
                      return InkWell(
                        onTap:
                            cnt.likeLoading
                                ? null
                                : () {
                                  setOrRemoveLike(
                                    widget.postDataObject,
                                    profileDataModel!,
                                    collectionPostReference,
                                    collectionUserReference,
                                    setState,
                                  );
                                  if (!widget.postDataObject.likesUsers
                                      .contains(
                                        profileDataModel?.mobileNumber ?? "",
                                      )) {
                                    _triggerHeartAnimation();
                                  }
                                },
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: cnt.likeLoading ? 0.5 : 1.0,
                              child: ButtonPosts(
                                width: Get.width,
                                img:
                                    !widget.postDataObject.likesUsers.contains(
                                          profileDataModel?.mobileNumber ?? "",
                                        )
                                        ? "assets/heartwhiteTemp.png"
                                        : "assets/heartredTemp.png",
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: AutoSizeText(
                                "${widget.postDataObject.numberOfLikes}",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CommentScreen(
                                postId: widget.postDataObject.key,
                              ),
                        ),
                      );
                    },
                    child: ButtonPosts(width: Get.width, img: "assets/cmt.png"),
                  ),
                  InkWell(
                    onTap: () {
                      setOrRemoveSaved(
                        widget.postDataObject,
                        profileDataModel!,
                        collectionUserReference,
                        setState,
                      );
                    },
                    child: Column(
                      children: [
                        ButtonPosts(
                          width: Get.width * 1.2,
                          img:
                              profileDataModel?.savedPosts.contains(
                                        widget.postDataObject.key,
                                      ) ==
                                      false
                                  ? "assets/add_icon.png"
                                  : "assets/remove_icon.png",
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.bookmark_border, size: 40),
                    itemBuilder:
                        (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'create_new',
                            child: Text('Create new catalog'),
                          ),
                          const PopupMenuItem(
                            value: 'existing',
                            child: Text('Add to existing catalog'),
                          ),
                        ],
                    onSelected: (String value) async {
                      if (value == 'create_new') {
                        final catalogName = await showDialog<String>(
                          context: context,
                          builder: (BuildContext context) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              title: const Text('New Catalog'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'Enter catalog name',
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: const Text('Create'),
                                  onPressed: () {
                                    Navigator.of(context).pop(controller.text);
                                  },
                                ),
                              ],
                            );
                          },
                        );

                        if (catalogName != null && catalogName.isNotEmpty) {
                          try {
                            final catalog = await CatalogRepository()
                                .createCatalog(
                                  userId: profileDataModel?.mobileNumber ?? "",
                                  name: catalogName,
                                );

                            await CatalogRepository().addItemToCatalog(
                              catalogId: catalog.id,
                              itemId: widget.postDataObject.key,
                              type: 'post',
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to new catalog!'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      } else if (value == 'existing') {
                        final selectedCatalog = await showDialog<Catalog>(
                          context: context,
                          builder: (BuildContext context) {
                            return Dialog(
                              child: FutureBuilder<List<Catalog>>(
                                future:
                                    CatalogRepository()
                                        .getUserCatalogs(
                                          profileDataModel?.mobileNumber ?? "",
                                        )
                                        .first,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No catalogs found. Create one first.',
                                      ),
                                    );
                                  }

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          'Select a catalog',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const Divider(),
                                      Expanded(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: snapshot.data!.length,
                                          itemBuilder: (context, index) {
                                            final catalog =
                                                snapshot.data![index];
                                            return ListTile(
                                              title: Text(catalog.name),
                                              onTap: () {
                                                Navigator.of(
                                                  context,
                                                ).pop(catalog);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        );

                        if (selectedCatalog != null) {
                          try {
                            await CatalogRepository().addItemToCatalog(
                              catalogId: selectedCatalog.id,
                              itemId: widget.postDataObject.key,
                              type: 'post',
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added to ${selectedCatalog.name}!',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      }
                    },
                  ),
                  if (widget.isCurrentUser)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _navigateToEditScreen(
                            context,
                            widget.postDataObject,
                            profileDataModel!,
                          );
                        } else if (value == 'delete') {
                          showDeleteConfirmation(
                            context,
                            widget.postDataObject,
                            collectionPostReference,
                          );
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit Post'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Post'),
                            ),
                          ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfirmDialogueBox extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String confirmText;
  final String cancelText;

  const ConfirmDialogueBox({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    required this.onCancel,
    this.confirmText = 'Delete',
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(cancelText, style: TextStyle(color: Colors.grey[600])),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(confirmText, style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
