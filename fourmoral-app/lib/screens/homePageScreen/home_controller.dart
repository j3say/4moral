import 'dart:developer';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
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
    if (!profileDataFetched.value && userPhoneNumber != null) {
      collectionUserReference
          .where('mobileNumber', isEqualTo: userPhoneNumber)
          .snapshots()
          .listen(
            (snapshots) {
              if (snapshots.docs.isNotEmpty) {
                profileDataModel = profileDataServices(snapshots.docs[0]);
              }
              profileDataFetched.value = true;
            },
            onError: (e) {
              print("Error getting profile: $e");
              profileDataFetched.value = true;
            },
          );
    }
  }

  Future<void> getPostAndStoryData() async {
    if (!contactsDataFetched.value ||
        !postDataFetched.value ||
        !storyDataFetched.value) {
      try {
        // Get contacts with error handling
        List<Contact> contacts = await FlutterContacts.getContacts(
          withThumbnail: false,
        ).catchError((e) {
          print("Error getting contacts: $e");
          return <Contact>[];
        });

        // Process contacts with null checks
        for (var contact in contacts) {
          for (var phone in contact.phones) {
            final cleanedNumber = phone.number
                .toString()
                .replaceAll(' ', '')
                .replaceAll('-', '');

            if (!cleanedNumber.contains("+91") &&
                !cleanedNumber.contains("+")) {
              contactsString = "$contactsString+91$cleanedNumber//";
            } else {
              contactsString = "$contactsString$cleanedNumber//";
            }
          }
        }

        // Post data listener with improved error handling
        collectionPostReference.orderBy('dateTime').snapshots().listen((
          snapshots,
        ) {
          try {
            realPostDataList.clear();
            for (var element in snapshots.docs) {
              // Null-safe URL handling
              final urls = List<String>.from(element.get('urls') ?? []);
              print("🔄 Post ${element.id} URLs: $urls");

              if (urls.isEmpty) {
                print("⚠️ Skipping post ${element.id} - empty URLs");
                continue;
              }

              // Null-safe mobile number check
              final mobileNumber =
                  element.get('mobileNumber')?.toString() ?? '';

              // Ensure profileDataModel is not null before accessing properties
              if (profileDataModel != null) {
                if (contactsString.contains(mobileNumber) &&
                    !profileDataModel!.block.contains(mobileNumber)) {
                  realPostDataList.add(postDataServices(element, "contacts"));
                } else if (profileDataModel!.followMentors.contains(
                      mobileNumber,
                    ) &&
                    !profileDataModel!.block.contains(mobileNumber)) {
                  realPostDataList.add(postDataServices(element, "following"));
                } else if (profileDataModel!.mobileNumber == mobileNumber) {
                  realPostDataList.add(postDataServices(element, "self"));
                }
              }
            }
            postDataList.value = realPostDataList.reversed.toList();
            postDataFetched.value = true;
            contactsDataFetched.value = true;
          } catch (e) {
            print("Error processing posts: $e");
            postDataFetched.value =
                true; // Still set to true to avoid infinite loading
          }
        }, onError: (e) => print("Posts stream error: $e"));
      } catch (e) {
        print("Error in getPostAndStoryData: $e");
        // Ensure we don't get stuck in loading state
        contactsDataFetched.value = true;
        postDataFetched.value = true;
        storyDataFetched.value = true;
      }
    }
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
