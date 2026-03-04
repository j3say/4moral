// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

import 'package:flutter/material.dart';
import 'package:fourmoral/screens/messageScreen/message_screen.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:fourmoral/screens/story/user_story.dart';
import 'package:get/get.dart';
import 'package:story_view/story_view.dart';

class StoryViewPage extends StatefulWidget {
  final UserStory userStory;
  final int initialIndex;
  final bool myStory;

  const StoryViewPage({
    super.key,
    required this.userStory,
    this.initialIndex = 0,
    this.myStory = false,
  });

  @override
  _StoryViewPageState createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> {
  final story2Controller = StoryController();
  final storyItems = <StoryItem>[];
  final Story2Controller getxStory2Controller = Get.put(Story2Controller());
  final TextEditingController replyController = TextEditingController();
  int _currentStoryIndex = 0;
  final Map<int, List<String>> _viewedUsersMap = {};
  final Map<int, List<DateTime>> _viewedTimestampsMap = {};
  bool _hasLoadedViews = false; // Track if views have been loaded

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialIndex;
    _loadStories();
  }

  Future<void> _loadViewedUsers() async {
    if (!widget.myStory || _hasLoadedViews) return;

    for (int i = 0; i < widget.userStory.stories.length; i++) {
      final story = widget.userStory.stories[i];
      final viewers = story.viewedBy;

      // Fetch usernames and profile pics for each viewer ID
      final userData = await _fetchUserData(viewers);

      setState(() {
        _viewedUsersMap[i] =
            userData.map((e) => e['username']).toList().cast<String>();
        _viewedTimestampsMap[i] = List.generate(
          viewers.length,
          (index) => story.createdAt,
        );
        _hasLoadedViews = true;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserData(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return [];

    final userData = <Map<String, dynamic>>[];
    final firestore = FirebaseFirestore.instance;

    for (final userId in userIds) {
      try {
        final doc =
            await firestore
                .collection('Users')
                .where('uniqueId', isEqualTo: userId)
                .get();
        if (doc.docs.isNotEmpty) {
          userData.add({
            'username': doc.docs.first.data()['username'] ?? 'Unknown User',
            'profilePicture': doc.docs.first.data()['profilePicture'],
          });
        } else {
          userData.add({'username': 'Unknown User', 'profilePicture': null});
        }
      } catch (e) {
        debugPrint('Error fetching user data for $userId: $e');
        userData.add({'username': 'Unknown User', 'profilePicture': null});
      }
    }

    return userData;
  }

  void _loadStories() {
    for (var story in widget.userStory.stories) {
      // Create a custom caption widget that includes profile picture and username
      Widget captionWidget = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Profile picture
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  widget.userStory.profilePic.isNotEmpty
                      ? NetworkImage(widget.userStory.profilePic)
                      : null,
              child:
                  widget.userStory.profilePic.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
            ),
            const SizedBox(width: 8),
            // Username
            Text(
              widget.userStory.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

      if (story.type == StoryType.image) {
        storyItems.add(
          StoryItem.pageImage(
            url: story.mediaUrl,
            controller: story2Controller,
            caption: Text(
              widget.userStory.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else {
        storyItems.add(
          StoryItem.pageVideo(
            story.mediaUrl,
            controller: story2Controller,
            caption: captionWidget,
          ),
        );
      }
    }
  }

  void _showViewedUsersSheet() {
    if (!widget.myStory) return;

    final currentViewers = _viewedUsersMap[_currentStoryIndex] ?? [];
    final currentStory = widget.userStory.stories[_currentStoryIndex];
    final userData = _fetchUserData(currentStory.viewedBy);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: userData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userDataList = snapshot.data ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Viewed by (${currentViewers.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _refreshViewedUsers();
                          _showViewedUsersSheet();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        currentViewers.isEmpty
                            ? const Center(child: Text('No views yet'))
                            : ListView.builder(
                              itemCount: currentViewers.length,
                              itemBuilder: (context, index) {
                                final user = userDataList[index];
                                return SizedBox(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          user['profilePicture'] != null
                                              ? NetworkImage(
                                                user['profilePicture'],
                                              )
                                              : null,
                                      child:
                                          user['profilePicture'] == null
                                              ? const Icon(Icons.person)
                                              : null,
                                    ),
                                    title: Text(user['username']),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshViewedUsers() async {
    if (!widget.myStory) return;

    // Refresh the current story's viewed users
    final currentStory = widget.userStory.stories[_currentStoryIndex];
    final doc =
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(currentStory.id)
            .get();

    if (doc.exists) {
      final updatedStory = Story2Model.fromJson(doc.data()!);
      final userData = await _fetchUserData(updatedStory.viewedBy);

      setState(() {
        _viewedUsersMap[_currentStoryIndex] =
            userData.map((e) => e['username']).toList().cast<String>();
        _viewedTimestampsMap[_currentStoryIndex] = List.generate(
          updatedStory.viewedBy.length,
          (index) => updatedStory.createdAt,
        );
      });
    }
  }

  // Method to handle sending the reply
  void _sendReply() {
    if (replyController.text.trim().isEmpty) return;

    // Get current story data for the reply
    final currentStory = widget.userStory.stories[_currentStoryIndex];
    final storyImage = currentStory.mediaUrl;
    final replyText = replyController.text;

    // Navigate to Message screen with the reply info
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Message(
              userimg: widget.userStory.profilePic,
              username: widget.userStory.username,
              profileuserphone:
                  widget
                      .userStory
                      .mobileNumber, // You might need to add this field to your UserStory model
              storyReply: replyText,
              storyImage: storyImage,
            ),
      ),
    );

    // Clear reply text
    replyController.clear();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> deleteStory(String storyId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('stories').doc(storyId).delete();

      final currentUser = FirebaseAuth.instance.currentUser;

      final storageRef = _storage
          .ref()
          .child('stories')
          .child(currentUser?.uid ?? "")
          .child(storyId);
      print("Failed to delete story:>>>${storageRef}");
      if (context.mounted) {
        Navigator.pop(context);
      }
      await storageRef.delete();
      print("Failed to delete story:>>>");

      await getxStory2Controller.fetchMyStories();

      Get.snackbar('Success', 'Story deleted successfully');
    } catch (e) {
      // print("Failed to delete story: $e");
      await getxStory2Controller.fetchMyStories();

      Get.snackbar('Error', 'Failed to delete story: $e');
    }
  }

  @override
  void dispose() {
    story2Controller.dispose();
    replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          storyItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StoryView(
                storyItems: storyItems,
                controller: story2Controller,
                onStoryShow: (storyItem, index) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _currentStoryIndex = index;
                    });
                    if (index >= 0 && index < widget.userStory.stories.length) {
                      // Load views on first click
                      if (!_hasLoadedViews) {
                        _loadViewedUsers();
                      }
                      getxStory2Controller.markStoryAsViewed(
                        widget.userStory.stories[index],
                      );
                    }
                  });
                },
                onComplete: () => Navigator.pop(context),
                progressPosition: ProgressPosition.top,
                inline: false,
                repeat: false,
              ),
          if (widget.myStory)
            Positioned(
              bottom: 80, // Moved up to make room for reply field
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _showViewedUsersSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_viewedUsersMap[_currentStoryIndex]?.length ?? 0} views',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.myStory)
            Positioned(
              top: 45,
              right: 10,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    // height: 30,
                    // width: 30,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 02,
                      vertical: 02,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        // onSelected:
                        //     (value) => deleteStory(
                        //       widget.userStory.stories[_currentStoryIndex].id,
                        //     ),
                        onSelected: (value) async {
                          // print(
                          //   "onSelectedonSelected${widget.userStory.stories[_currentStoryIndex].id}",
                          // );
                          await deleteStory(
                            widget.userStory.stories[_currentStoryIndex].id,
                          );
                        },
                        icon: Icon(Icons.more_vert, color: Colors.white),
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!widget
              .myStory) // Only show reply field if it's not the user's own story
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        decoration: InputDecoration(
                          hintText: 'Reply to story',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _sendReply,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
