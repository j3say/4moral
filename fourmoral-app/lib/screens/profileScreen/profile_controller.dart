import 'dart:developer';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/ask_model.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/story_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/models/user_profile_post_model.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/homePageScreen/home_controller.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen_services.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ProfileController extends GetxController {
  final homeCnt = Get.put(HomeCnt());
  final contactsScreenCnt = Get.put(ContactsScreenCnt());

  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');
  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');
  DatabaseReference refFirebaseStory = FirebaseDatabase.instance.ref().child(
    'Stories',
  );
  CollectionReference selectedContactsCollection = FirebaseFirestore.instance
      .collection('SelectedContacts');

  final TextEditingController annController = TextEditingController();
  final controller = StoryController();

  RxBool privateAccount = false.obs;
  bool likeLoading = false;
  RxBool contactAccount = false.obs;
  RxBool isLoadingPrivate = false.obs;
  RxBool isLoadingContact = false.obs;
  RxBool userProfilePostDataFetched = false.obs;
  RxBool memoriesDataFetched = false.obs;
  RxBool isSaving = false.obs; // Renamed from isSharing to isSaving

  var followingCount = 0.obs;
  var contactsCount = 0.obs;

  RxList<ProfilePageStoryModel> profileStoryDataList =
      <ProfilePageStoryModel>[].obs;
  RxList<UserProfilePostModel> userProfilePostDataPhotoList =
      <UserProfilePostModel>[].obs;
  RxList<UserProfilePostModel> userProfilePostDataVideoList =
      <UserProfilePostModel>[].obs;
  RxList<UserProfilePostModel> allPosts = <UserProfilePostModel>[].obs;
  RxList<RecordingModel> annList = <RecordingModel>[].obs;
  RxList<StoryModel> storyDataList = <StoryModel>[].obs;

  ProfileModel? profileDataObject;
  String? userPhoneNumber;
  Map? profileValuesStory;

  // Count getters
  int get totalStories => profileStoryDataList.length;
  int get totalPhotos => userProfilePostDataPhotoList.length;
  int get totalVideos => userProfilePostDataVideoList.length;
  int get totalMediaCount => totalStories + totalPhotos + totalVideos;

  @override
  void onInit() {
    super.onInit();
    // Listen to Firestore changes for profile data
    if (userPhoneNumber != null) {
      collectionUserReference
          .where('mobileNumber', isEqualTo: userPhoneNumber)
          .snapshots()
          .listen((snapshots) {
            if (snapshots.docs.isNotEmpty) {
              profileDataObject = profileDataServices(snapshots.docs[0]);
              privateAccount.value = profileDataObject?.privateAccount ?? false;
              contactAccount.value = profileDataObject?.contactAccount ?? false;
              getUserProfilePostData();
              getMemoriesList();
              fetchCounts();
            }
          });
    }
  }

  Future<void> initialize(ProfileModel? profile, String? phoneNumber) async {
    profileDataObject = profile;
    userPhoneNumber = phoneNumber;
    privateAccount.value = profile?.privateAccount ?? false;
    contactAccount.value = profile?.contactAccount ?? false;
    if (profile != null && phoneNumber != null) {
      await getUserProfilePostData();
      await getMemoriesList();
      await fetchCounts();
    }
  }

  Future<void> togglePrivateAccount(bool newValue) async {
    if (isLoadingPrivate.value || userPhoneNumber == null) return;

    isLoadingPrivate.value = true;
    try {
      final userDoc =
          await collectionUserReference
              .where('mobileNumber', isEqualTo: userPhoneNumber)
              .get();

      if (userDoc.docs.isEmpty) {
        flutterShowToast("User not found");
        isLoadingPrivate.value = false;
        return;
      }

      final isVerified = userDoc.docs[0]['verified'] ?? false;
      if (!isVerified && newValue == false) {
        flutterShowToast("Please verify your account to make it public");
        isLoadingPrivate.value = false;
        return;
      }

      await userDoc.docs[0].reference.update({'privateAccount': newValue});
      privateAccount.value = newValue;
      flutterShowToast(
        newValue ? "Private Account Activated" : "Public Account Activated",
      );
    } catch (e) {
      flutterShowToast("Error updating account status");
    } finally {
      isLoadingPrivate.value = false;
    }
  }

  Future<void> toggleContactAccount(bool newValue) async {
    if (isLoadingContact.value || userPhoneNumber == null) return;

    isLoadingContact.value = true;
    try {
      final userDoc =
          await collectionUserReference
              .where('mobileNumber', isEqualTo: userPhoneNumber)
              .get();

      if (userDoc.docs.isEmpty) {
        flutterShowToast("User not found");
        isLoadingContact.value = false;
        return;
      }

      await userDoc.docs[0].reference.update({'contactAccount': newValue});
      contactAccount.value = newValue;
      flutterShowToast(
        newValue
            ? "Contact Private Account Activated"
            : "Contact Public Account Activated",
      );
    } catch (e) {
      flutterShowToast("Error updating contact account status");
    } finally {
      isLoadingContact.value = false;
    }
  }

  // Helper function to safely extract URLs
  List<String> _safeGetUrls(DocumentSnapshot doc) {
    try {
      final rawUrls = doc.get('urls') ?? doc.get('url');
      if (rawUrls is List) {
        return rawUrls.whereType<String>().toList();
      } else if (rawUrls is String) {
        return [rawUrls];
      }
      log("⚠️ URLs field has unexpected type: ${rawUrls.runtimeType}");
      return [];
    } catch (e) {
      log("⚠️ Error getting URLs for post ${doc.id}: $e");
      return [];
    }
  }

  // Generate thumbnail for video posts
  Future<String?> generateThumbnail(String videoUrl) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      log('Error generating thumbnail for $videoUrl: $e');
      return null;
    }
  }

  Future<void> fetchCounts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
      final followingSnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .collection('following')
              .get();
      followingCount.value = followingSnapshot.docs.length;
      contactsCount.value = contactsScreenCnt.validContactsCount.value;
    } catch (e) {
      log('Error fetching counts: $e');
    }
  }

  Future<void> getUserProfilePostData() async {
    try {
      userProfilePostDataFetched.value = false;
      await fetchCounts();
      final snapshots =
          await collectionPostReference
              .orderBy('dateTime')
              .where('mobileNumber', isEqualTo: profileDataObject?.mobileNumber)
              .get();

      final photoPosts = <UserProfilePostModel>[];
      final videoPosts = <UserProfilePostModel>[];
      final allPostsTemp = <UserProfilePostModel>[];

      for (var doc in snapshots.docs) {
        final urls = _safeGetUrls(doc);
        if (urls.isEmpty) {
          log('⚠️ Skipping post ${doc.id} - no valid URLs');
          continue;
        }

        String thumbnail = urls.first;
        if (doc.get('type') == 'Video') {
          thumbnail =
              doc.get('thumbnail') ??
              await generateThumbnail(urls.first) ??
              urls.first;
        }

        final post =
            doc.get('type') == 'Post'
                ? userProfilePostPhotoDataServices(doc)
                : userProfilePostVideoDataServices(doc);

        if (doc.get('type') == 'Post') {
          photoPosts.add(post);
        } else if (doc.get('type') == 'Video') {
          videoPosts.add(post);
        }
        allPostsTemp.add(post);
      }

      userProfilePostDataPhotoList.assignAll(photoPosts);
      userProfilePostDataVideoList.assignAll(videoPosts);
      allPosts.assignAll(allPostsTemp);

      userProfilePostDataFetched.value = true;
      log(
        'Fetched ${photoPosts.length} photos and ${videoPosts.length} videos',
      );
    } catch (e) {
      log('Error fetching posts: $e');
      userProfilePostDataFetched.value = true;
    }
  }

  Future<void> getMemoriesList() async {
    try {
      memoriesDataFetched.value = false;
      final event =
          await refFirebaseStory
              .child(profileDataObject?.mobileNumber ?? '')
              .child('data')
              .once();

      profileStoryDataList.clear();
      storyDataList.clear();

      if (event.snapshot.value == null) {
        log('ℹ️ No stories found for this user');
        memoriesDataFetched.value = true;
        return;
      }

      try {
        Map values = event.snapshot.value as Map;
        profileValuesStory = values;

        values.forEach((key, value) {
          final mediaUrl =
              value['url']?.toString() ?? value['thumbnail']?.toString() ?? '';
          if (mediaUrl.isEmpty) {
            log('⚠️ Skipping story $key - missing media URL');
            return;
          }

          profileStoryDataList.add(
            ProfilePageStoryModel(
              key,
              mediaUrl,
              value['caption']?.toString() ?? '',
            ),
          );
        });
      } catch (e) {
        log('⚠️ Error processing stories: $e');
      }

      memoriesDataFetched.value = true;
      log('Fetched ${profileStoryDataList.length} stories');
    } catch (e) {
      log('Error fetching memories: $e');
      memoriesDataFetched.value = true;
    }
  }

  Future<void> saveSelectedContacts(List<ContactsModel> contacts) async {
    if (!contactAccount.value) {
      flutterShowToast("Enable Contact Private mode to select contacts");
      return;
    }

    try {
      isSaving.value = true;
      final userPhoneNumber = profileDataObject?.mobileNumber ?? '';
      if (userPhoneNumber.isEmpty) {
        flutterShowToast("User phone number not found");
        isSaving.value = false;
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final selectedContactsRef = selectedContactsCollection
          .doc(userPhoneNumber)
          .collection('Data');

      // Clear existing contacts to avoid duplicates (optional, remove if you want to append)
      final existingDocs = await selectedContactsRef.get();
      for (var doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      for (var contact in contacts) {
        final docRef = selectedContactsRef.doc();
        batch.set(docRef, {
          'receiverId': contact.uniqueId,
          'receiverPhoneNumber': contact.mobileNumber,
          'receiverName': contact.name,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      flutterShowToast("Contacts saved successfully");
    } catch (e) {
      log('Error saving contacts: $e');
      flutterShowToast("Error saving contacts");
    } finally {
      isSaving.value = false;
    }
  }
}
