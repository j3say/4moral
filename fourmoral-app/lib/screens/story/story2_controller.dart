import 'dart:developer';
import 'dart:io';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:fourmoral/screens/story/user_story.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Story2Controller extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<UserStory> userStories = <UserStory>[].obs;
  final RxList<UserStory> myStories = <UserStory>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isUploading = false.obs;
  final RxBool isUserInitialized = false.obs;

  String currentUserId = '';
  String currentUserMobileNumber = '';
  String currentUsername = '';

  @override
  void onInit() {
    super.onInit();
    initializeAndFetch();
  }

  Future<void> initializeAndFetch() async {
    try {
      isLoading.value = true;
      await initializeUserData();

      if (isUserInitialized.value) {
        await Future.wait([_fetchAllStories(), fetchMyStories()]);
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      _showSafeSnackbar('Error', 'Failed to load stories');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> initializeUserData() async {
    try {
      currentUserMobileNumber =
          AppPreference().getString(PreferencesKey.userPhoneNumber) ?? '';

      if (currentUserMobileNumber.isEmpty) {
        throw Exception('No mobile number found');
      }

      final userDoc =
          await _firestore
              .collection('Users')
              .where('mobileNumber', isEqualTo: currentUserMobileNumber)
              .limit(1)
              .get();

      if (userDoc.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userData = userDoc.docs.first.data();
      currentUserId = userData['uid']?.toString() ?? '';
      currentUsername = userData['username']?.toString() ?? '';

      if (currentUserId.isEmpty) {
        throw Exception('Invalid user data');
      }

      isUserInitialized.value = true;
    } catch (e) {
      debugPrint('User initialization failed: $e');
      currentUserId = '';
      currentUsername = '';
      isUserInitialized.value = false;
      rethrow;
    }
  }

  Future<void> _fetchAllStories() async {
    if (!isUserInitialized.value) return;

    try {
      // First get the current user's followMentors data
      final userDoc =
          await _firestore
              .collection('Users')
              .where('uid', isEqualTo: currentUserId)
              .limit(1)
              .get();


      if (userDoc.docs.isEmpty) return;

      final userData = userDoc.docs.first.data();
      final followMentorsString = userData['followMentors']?.toString() ?? '';

      // Split the followMentors string into individual phone numbers
      final followedNumbers =
          followMentorsString
              .split('//')
              .where((number) => number.isNotEmpty)
              .toSet(); // Using Set for faster lookups

      final now = DateTime.now();
      final storiesSnapshot =
          await _firestore
              .collection('stories')
              .where('expiresAt', isGreaterThan: now.toIso8601String())
              .get();


      final storiesByUser = <String, List<Story2Model>>{};

      for (final doc in storiesSnapshot.docs) {
        try {
          final story = Story2Model.fromJson(doc.data());



          // Skip if story has no user ID or current user is restricted
          if (story.userId.isEmpty ||
              story.restrictedUsers.contains(currentUsername)) {
            continue;
          }

          // Check if the story's mobileNumber is in the followedNumbers set
          if (followedNumbers.contains(story.mobileNumber)) {
            storiesByUser.putIfAbsent(story.userId, () => []).add(story);
          }
        } catch (e) {
          debugPrint('Error processing story ${doc.id}: $e');
        }
      }
      userStories.value = await _buildUserStories(storiesByUser);

    } catch (e) {
      debugPrint('Error fetching stories: $e');
      _showSafeSnackbar('Error', 'Failed to load stories');
    }
  }

  Future<List<UserStory>> _buildUserStories(
    Map<String, List<Story2Model>> storiesByUser,
  ) async {
    final stories = <UserStory>[];

    for (final userId in storiesByUser.keys) {
      try {
        final userDoc =
            await _firestore
                .collection('Users')
                .where('uid', isEqualTo: userId)
                .limit(1)
                .get();

        final userData =
            userDoc.docs.isNotEmpty ? userDoc.docs.first.data() : {};


        stories.add(
          UserStory(
            userId: userId,
            username: userData['username']?.toString() ?? 'Unknown',
            profilePic: userData['profilePicture']?.toString() ?? '',
            stories: storiesByUser[userId] ?? [],
            hasUnseenStories: (storiesByUser[userId] ?? []).any(
              (story) => !story.viewedBy.contains(currentUserId),
            ),
            mobileNumber: userData['mobileNumber']?.toString() ?? '',
          ),
        );
      } catch (e) {
        debugPrint('Error building story for user $userId: $e');
        stories.add(
          UserStory(
            userId: userId,
            username: 'Unknown',
            profilePic: '',
            stories: storiesByUser[userId] ?? [],
            hasUnseenStories: true,
            mobileNumber: '',
          ),
        );
      }
    }

    return stories;
  }

  Future<void> fetchMyStories() async {
    if (!isUserInitialized.value) return;

    try {
      final now = DateTime.now();
      final snapshot =
          await _firestore
              .collection('stories')
              .where('userId', isEqualTo: currentUserId)
              .where('expiresAt', isGreaterThan: now.toIso8601String())
              .get();

      final stories =
          snapshot.docs
              .map((doc) => Story2Model.fromJson(doc.data()))
              .where((story) => story.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));


      if (stories.isNotEmpty) {
        final userDoc =
            await _firestore
                .collection('Users')
                .where('uid', isEqualTo: currentUserId)
                .limit(1)
                .get();



        if (userDoc.docs.isNotEmpty) {
          final userData = userDoc.docs.first.data();
          log("userData ${userData['mobileNumber']}");

          myStories.value = [
            UserStory(
              userId: currentUserId,
              username: currentUsername,
              profilePic: userData['profilePicture'],
              stories: stories,
              hasUnseenStories: false,
              mobileNumber: userData['mobileNumber'],
            ),
          ];

          log("userData ${myStories.value}");
        }
      } else {
        myStories.value = [];
      }
    } catch (e) {
      debugPrint('Error fetching my stories: $e');
      _showSafeSnackbar('Error', 'Failed to load your stories');
    }
  }

  void _showSafeSnackbar(String title, String message) {
    // Only show snackbar if context is available and overlay is ready
    if (Get.context != null && Get.isSnackbarOpen) Get.back();
    if (Get.context != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } else {
      debugPrint('Snackbar not shown: No context available');
    }
  }

  // Upload story to Firebase
  Future<void> uploadStory(
      File media,
      StoryType type, {
        String caption = '',
        List<String> restrictedUsers = const [],
        File? thumbnailFile,
      }) async {
    isUploading.value = true;
    try {
      final String storyId = const Uuid().v4();
      final String extension = path.extension(media.path);

      // Upload media file
      final storageRef = _storage
          .ref()
          .child('stories')
          .child(currentUserId)
          .child('$storyId$extension');
      final uploadTask = storageRef.putFile(media);
      final snapshot = await uploadTask.whenComplete(() {});
      final mediaUrl = await snapshot.ref.getDownloadURL();

      // Upload thumbnail for videos
      String? thumbnailUrl;
      if (type == StoryType.video && thumbnailFile != null) {
        final thumbnailRef = _storage
            .ref()
            .child('stories')
            .child(currentUserId)
            .child('thumbnails')
            .child('thumb_$storyId.jpg');
        final thumbnailUploadTask = thumbnailRef.putFile(thumbnailFile);
        final thumbnailSnapshot = await thumbnailUploadTask.whenComplete(() {});
        thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      }

      // Create story model
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));
      final story = Story2Model(
        id: storyId,
        userId: currentUserId,
        mobileNumber: AppPreference().getString(PreferencesKey.userPhoneNumber),
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl ?? mediaUrl, // Use mediaUrl for photos
        type: type,
        createdAt: now,
        expiresAt: expiresAt,
        caption: caption,
        restrictedUsers: restrictedUsers,
      );

      // Save to Firestore
      await _firestore.collection('stories').doc(storyId).set(story.toJson());

      // Update local stories
      await fetchMyStories();
      Get.snackbar('Success', 'Story uploaded successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload story: $e');
      debugPrint('Error uploading story: $e');
    } finally {
      isUploading.value = false;
    }
  }

  // Delete a story
  Future<void> deleteStory(String storyId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('stories').doc(storyId).delete();

      // Delete from storage
      final storageRef = _storage
          .ref()
          .child('stories')
          .child(currentUserId)
          .child(storyId);
      await storageRef.delete();

      // Refresh my stories
      await fetchMyStories();
      Get.snackbar('Success', 'Story deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete story: $e');
    }
  }

  // Mark story as viewed
  Future<void> markStoryAsViewed(Story2Model story) async {
    if (!story.viewedBy.contains(currentUserId)) {
      final updatedViewedBy = [...story.viewedBy, currentUserId];
      await _firestore.collection('stories').doc(story.id).update({
        'viewedBy': updatedViewedBy,
      });

      // Update local state
      final index = userStories.indexWhere((us) => us.userId == story.userId);
      if (index != -1) {
        final userStory = userStories[index];
        final storyIndex = userStory.stories.indexWhere(
          (s) => s.id == story.id,
        );
        if (storyIndex != -1) {
          final updatedStory = userStory.stories[storyIndex].copyWith(
            viewedBy: updatedViewedBy,
          );
          final updatedStories = List<Story2Model>.from(userStory.stories);
          updatedStories[storyIndex] = updatedStory;

          final hasUnseenStories = updatedStories.any(
            (s) => !s.viewedBy.contains(currentUserId),
          );

          final updatedUserStory = UserStory(
            userId: userStory.userId,
            username: userStory.username,
            profilePic: userStory.profilePic,
            stories: updatedStories,
            hasUnseenStories: hasUnseenStories,
            mobileNumber: userStory.mobileNumber,
          );

          final updatedUserStories = List<UserStory>.from(userStories);
          updatedUserStories[index] = updatedUserStory;
          userStories.value = updatedUserStories;
        }
      }
    }
  }

  // Add user to restricted list
  Future<void> restrictUserFromStory(String storyId, String username) async {
    try {
      // Find user by username
      final userQuery =
          await _firestore
              .collection('Users')
              .where('username', isEqualTo: username)
              .get();

      if (userQuery.docs.isEmpty) {
        Get.snackbar('Error', 'User not found');
        return;
      }

      final userId = userQuery.docs.first.id;

      // Update story restrictions
      final storyDoc =
          await _firestore.collection('stories').doc(storyId).get();
      if (storyDoc.exists) {
        final story = Story2Model.fromJson(storyDoc.data()!);
        if (!story.restrictedUsers.contains(userId)) {
          await _firestore.collection('stories').doc(storyId).update({
            'restrictedUsers': [...story.restrictedUsers, userId],
          });

          Get.snackbar('Success', 'User restricted from viewing this story');
          await fetchMyStories();
        } else {
          Get.snackbar('Info', 'User is already restricted from this story');
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to restrict user: $e');
    }
  }

  // Remove user from restricted list
  Future<void> removeRestriction(String storyId, String userId) async {
    try {
      final storyDoc =
          await _firestore.collection('stories').doc(storyId).get();
      if (storyDoc.exists) {
        final story = Story2Model.fromJson(storyDoc.data()!);
        final updatedRestrictions =
            story.restrictedUsers.where((id) => id != userId).toList();

        await _firestore.collection('stories').doc(storyId).update({
          'restrictedUsers': updatedRestrictions,
        });

        Get.snackbar('Success', 'Restriction removed');
        await fetchMyStories();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove restriction: $e');
    }
  }
}
