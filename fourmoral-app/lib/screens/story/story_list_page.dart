import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:fourmoral/screens/story/story_create_page.dart';
import 'package:fourmoral/screens/story/story_view_page.dart';
import 'package:get/get.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

class StoryListPage extends StatefulWidget {
  final ProfileModel? profileModel;

  const StoryListPage({super.key, this.profileModel});

  @override
  _StoryListPageState createState() => _StoryListPageState();
}

class _StoryListPageState extends State<StoryListPage> {
  final Story2Controller story2Controller = Get.put(Story2Controller());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _followerUsers = [];
  List<String> _restrictedUsers = [];
  bool _showUserSelection = false;
  bool _isLoadingUsers = false;
  String? _selectedStoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
                () => Get.to(
                  () => StoryCreatePage(profileModel: widget.profileModel),
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Obx(
            () =>
                story2Controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      children: [
                        // My stories section
                        if (story2Controller.myStories.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Your Stories',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      story2Controller.myStories.isNotEmpty
                                          ? story2Controller
                                                  .myStories[0]
                                                  .stories
                                                  .length +
                                              1
                                          : 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      // Add new story button
                                      return GestureDetector(
                                        onTap:
                                            () => Get.to(
                                              () => StoryCreatePage(
                                                profileModel:
                                                    widget.profileModel,
                                              ),
                                            ),
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          width: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.add,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      final story =
                                          story2Controller
                                              .myStories[0]
                                              .stories[index - 1];
                                      return GestureDetector(
                                        onTap: () {
                                          // Show options to edit or view
                                          showModalBottomSheet(
                                            context: context,
                                            builder: (context) {
                                              return Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.visibility,
                                                    ),
                                                    title: const Text(
                                                      'View Story',
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      Get.to(
                                                        () => StoryViewPage(
                                                          userStory:
                                                              story2Controller
                                                                  .myStories[0],
                                                          initialIndex:
                                                              index - 1,
                                                          myStory: true,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.block,
                                                    ),
                                                    title: const Text(
                                                      'Restrict Users',
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _selectedStoryId =
                                                          story.id;
                                                      _showFollowerSelectionPanel();
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.delete,
                                                    ),
                                                    title: const Text(
                                                      'Delete Story',
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      story2Controller
                                                          .deleteStory(
                                                            story.id,
                                                          );
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          width: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 2,
                                            ),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                story.type == StoryType.image
                                                    ? story.mediaUrl
                                                    : story2Controller
                                                        .myStories[0]
                                                        .profilePic,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          child:
                                              story.type == StoryType.video
                                                  ? const Center(
                                                    child: Icon(
                                                      Icons.play_arrow,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                  : null,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'All Stories',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        story2Controller.userStories.isEmpty
                            ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No stories available'),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: story2Controller.userStories.length,
                              itemBuilder: (context, index) {
                                final userStory =
                                    story2Controller.userStories[index];
                                return ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            userStory.hasUnseenStories
                                                ? Colors.blue
                                                : Colors.grey,
                                        width: 2,
                                      ),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          userStory.profilePic,
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  title: Text(userStory.username),
                                  subtitle: Text(
                                    '${userStory.stories.length} stories • ${_getTimeAgo(userStory.stories.first.createdAt)}',
                                  ),
                                  onTap:
                                      () => Get.to(
                                        () =>
                                            StoryViewPage(userStory: userStory),
                                      ),
                                );
                              },
                            ),
                      ],
                    ),
          ),

          // User Selection Panel (overlay)
          if (_showUserSelection)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showUserSelection = false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black54, // Semi-transparent background
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildUserSelectionPanel(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _toggleUserRestriction(String userId) {
    setState(() {
      if (_restrictedUsers.contains(userId)) {
        _restrictedUsers.remove(userId);
      } else {
        _restrictedUsers.add(userId);
      }
    });
  }

  Future<void> _fetchFollowersFromAllUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
        _followerUsers = [];
      });

      String? currentUserContact = widget.profileModel?.mobileNumber;
      if (currentUserContact == null || currentUserContact.isEmpty) {
        Get.snackbar('Error', 'Current user contact information not available');
        setState(() => _isLoadingUsers = false);
        return;
      }

      final querySnapshot = await _firestore.collection('Users').get();
      final List<Map<String, dynamic>> followers = [];

      for (var doc in querySnapshot.docs) {
        final userData = doc.data();
        final String? followMentors = userData['followMentors'] as String?;

        if (followMentors != null &&
            followMentors.contains(currentUserContact)) {
          followers.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown User',
            'contact': userData['contact'] ?? '',
            'avatar': userData['profilePicture'] ?? '',
          });
        }
      }

      // Fetch currently restricted users for this story to show as selected
      if (_selectedStoryId != null) {
        try {
          final storyDoc =
              await _firestore
                  .collection('Stories')
                  .doc(_selectedStoryId)
                  .get();
          if (storyDoc.exists) {
            final storyData = storyDoc.data();
            final List<dynamic> restricted =
                storyData?['restrictedUsers'] ?? [];
            setState(() {
              _restrictedUsers = List<String>.from(restricted);
            });
          }
        } catch (e) {
          print('Error fetching story restriction data: ${e.toString()}');
        }
      }

      setState(() {
        _followerUsers = followers;
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error fetching followers: ${e.toString()}');
      Get.snackbar('Error', 'Failed to load followers: ${e.toString()}');
      setState(() => _isLoadingUsers = false);
    }
  }

  void _showFollowerSelectionPanel() async {
    await _fetchFollowersFromAllUsers();
    setState(() => _showUserSelection = true);
  }

  Widget _buildUserSelectionPanel() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Text(
            'Hide story from',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Select followers who shouldn\'t see this story',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Divider(),
          _isLoadingUsers
              ? Center(child: CircularProgressIndicator())
              : _followerUsers.isEmpty
              ? Center(child: Text('No followers found'))
              : Expanded(
                child: ListView.builder(
                  itemCount: _followerUsers.length,
                  itemBuilder: (context, index) {
                    final user = _followerUsers[index];
                    final isRestricted = _restrictedUsers.contains(user['id']);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            user['avatar'].isNotEmpty
                                ? NetworkImage(user['avatar'])
                                : null,
                        child:
                            user['avatar'].isEmpty ? Icon(Icons.person) : null,
                      ),
                      title: Text(user['name']),
                      subtitle: Text(user['contact']),
                      trailing:
                          isRestricted
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, color: Colors.green),
                                  SizedBox(width: 8),
                                  Checkbox(
                                    value: true,
                                    onChanged:
                                        (value) =>
                                            _toggleUserRestriction(user['id']),
                                  ),
                                ],
                              )
                              : Checkbox(
                                value: false,
                                onChanged:
                                    (value) =>
                                        _toggleUserRestriction(user['id']),
                              ),
                      onTap: () => _toggleUserRestriction(user['id']),
                    );
                  },
                ),
              ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => setState(() => _showUserSelection = false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _updateStoryRestrictions,
                style: ElevatedButton.styleFrom(minimumSize: Size(200, 48)),
                child: Text('Save Restrictions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStoryRestrictions() async {
    if (_selectedStoryId == null) {
      Get.snackbar('Error', 'No story selected');
      return;
    }

    try {
      await _firestore.collection('stories').doc(_selectedStoryId).update({
        'restrictedUsers': _restrictedUsers,
      });

      Get.snackbar(
        'Success',
        'Story restrictions updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      setState(() => _showUserSelection = false);

      // Refresh stories to reflect the changes
      story2Controller.initializeAndFetch();
    } catch (e) {
      print('Error updating story restrictions: ${e.toString()}');
      Get.snackbar('Error', 'Failed to update restrictions: ${e.toString()}');
    }
  }
}
