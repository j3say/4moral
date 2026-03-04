import 'dart:developer';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_list_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:get/get.dart';
import 'package:story_view/controller/story_controller.dart';

class HomeCnt extends GetxController {
  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');

  DatabaseReference refFirebaseStory = FirebaseDatabase.instance.ref().child(
    'Stories',
  );

  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');

  final controller = StoryController();

  int tabInt = 0;

  RxList postDataList = [].obs;
  RxList<PostModel> realPostDataList = <PostModel>[].obs;

  RxBool postDataFetched = false.obs;
  RxBool contactsDataFetched = false.obs;
  RxBool storyDataFetched = false.obs;
  RxBool profileDataFetched = false.obs;

  Future<void> getUsersList() async {
    FirebaseDatabase.instance.ref().child("UsersList").onValue.listen((value) {
      String temp = "";
      temp = value.snapshot.value.toString();
      userList = temp.split("//");
      userList.removeLast();
    });
  }

  Future getProfileData({String? userPhoneNumber}) async {
    log("postDataFetched $postDataFetched");
    log("postDataFetched $userPhoneNumber");
    
    // ⚡ LIGHTNING FAST BYPASS: Mock the HolyPlace profile instantly
    if (!profileDataFetched.value) {
       // We inject a fake HolyPlace profile so the Prayer button activates!
       profileDataModel = ProfileModel(
          userPhoneNumber ?? "1234567890", // mobileNumber
          "https://via.placeholder.com/150", // profilePicture
          "HolyShrine", // username
          "HolyPlace", // type (CRITICAL FOR PRAYER FEATURE)
          "Welcome to our Shrine", // bio
          "UID123", // uniqueId
          "Shrine Name", // name
          "100", // age
          "Other", // gender
          "City Center", // address
          "shrine@test.com", // emailAddress
          "All", // religion
          "", // followMentors
          "", // likePosts
          "", // savedPosts
          "", // watchLater
          "", // block
          true, // verified
          false, // privateAccount
          [], // recording
          "65f0a1b2c3d4e5f6a7b8c9d0", // uId
          false // contactAccount
       );
       profileDataFetched.value = true;
       print("⚡ Lightning Mode: Profile injected as HolyPlace.");
    }
  }

  Future<void> getPostAndStoryData() async {
    // ⚡ LIGHTNING FAST BYPASS: Skip Firebase completely for Phase 1 testing
    contactsDataFetched.value = true;
    postDataFetched.value = true;
    storyDataFetched.value = true;
    
    // Feed it an empty list so the UI renders instantly without crashing
    postDataList.value = [];
    realPostDataList.clear();
    
    print("⚡ Lightning Mode: Feed bypassed for Phase 1 testing.");
  }

  Future<void> pullRefresh() async {
    try {
      contactsDataFetched.value = false;
      postDataFetched.value = false;
      storyDataFetched.value = false;
      contactsString = ""; // Reset contacts string
      await getPostAndStoryData();
    } catch (e) {
      print("Pull refresh error: $e");
      // Ensure we don't get stuck in loading state
      contactsDataFetched.value = true;
      postDataFetched.value = true;
      storyDataFetched.value = true;
    }
  }
}
