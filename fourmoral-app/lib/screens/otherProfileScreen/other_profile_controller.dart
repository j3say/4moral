import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/models/story_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/models/user_profile_post_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen_services.dart';
import 'package:get/get.dart';
import 'package:story_view/controller/story_controller.dart';

class OtherProfileCnt extends GetxController {
  RxBool otherProfileFetched = false.obs;
  RxBool privateAccount = false.obs;
  RxBool memoriesDataFetched = false.obs;
  ProfileModel? otherProfileDataModel;

  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');
  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');
  DatabaseReference refFirebaseStory = FirebaseDatabase.instance.ref().child(
    'Stories',
  );

  final controller = StoryController();

  RxList<ProfilePageStoryModel> profileStoryDataList =
      <ProfilePageStoryModel>[].obs;
  RxList<UserProfilePostModel> otherProfilePostDataPhotoList =
      <UserProfilePostModel>[].obs;
  RxList<UserProfilePostModel> otherProfilePostDataVideoList =
      <UserProfilePostModel>[].obs;

  // Count getters
  int get totalStories => profileStoryDataList.length;
  int get totalPhotos => otherProfilePostDataPhotoList.length;
  int get totalVideos => otherProfilePostDataVideoList.length;
  int get totalMediaCount => totalStories + totalPhotos + totalVideos;

  getOtherProfileData({String? mobileNumber}) {
    try {
      otherProfileFetched.value = false;
      collectionUserReference
          .where('mobileNumber', isEqualTo: otherProfileDataModel?.mobileNumber)
          .snapshots()
          .listen((event) {
            List<String> followingDataListTemp = event.docs.first
                .get('followMentors')
                .split("//");

            followingDataListTemp.removeLast();

            collectionUserReference
                .where('mobileNumber', isEqualTo: mobileNumber)
                .snapshots()
                .listen((snapshots) {
                  privateAccount.value = snapshots.docs.first.get(
                    'privateAccount',
                  );
                  otherProfileDataModel = profileDataServices(
                    snapshots.docs[0],
                  );

                  // Get posts
                  collectionPostReference
                      .orderBy('dateTime')
                      .snapshots()
                      .listen((snapshots) {
                        otherProfilePostDataPhotoList.clear();
                        otherProfilePostDataVideoList.clear();

                        if (!privateAccount.value) {
                          for (var element in snapshots.docs) {
                            if (otherProfileDataModel?.mobileNumber ==
                                element.get('mobileNumber').toString()) {
                              if (element.get('type').toString() == "Photo") {
                                otherProfilePostDataPhotoList.add(
                                  userProfilePostPhotoDataServices(element),
                                );
                              } else {
                                otherProfilePostDataVideoList.add(
                                  userProfilePostVideoDataServices(element),
                                );
                              }
                            }
                          }
                        } else {
                          for (var element in followingDataListTemp) {
                            if (element == mobileNumber) {
                              for (var element in snapshots.docs) {
                                if (otherProfileDataModel?.mobileNumber ==
                                    element.get('mobileNumber').toString()) {
                                  if (element.get('type').toString() ==
                                      "Photo") {
                                    otherProfilePostDataPhotoList.add(
                                      userProfilePostPhotoDataServices(element),
                                    );
                                  } else {
                                    otherProfilePostDataVideoList.add(
                                      userProfilePostVideoDataServices(element),
                                    );
                                  }
                                }
                              }
                            }
                          }
                        }

                        // Get stories
                        getOtherProfileStories(mobileNumber: mobileNumber);

                        otherProfileFetched.value = true;
                      });
                });
          });
    } catch (e) {
      rethrow;
    }
  }

  getOtherProfileStories({String? mobileNumber}) {
    if (!memoriesDataFetched.value) {
      refFirebaseStory.child(mobileNumber ?? "").child('data').onValue.listen((
        event,
      ) {
        profileStoryDataList.clear();

        if (event.snapshot.value == null) {
          print("ℹ️ No stories found for this user");
          return;
        }

        try {
          Map values = (event.snapshot.value) as Map;

          values.forEach((key, value) {
            // Safely extract story URL/thumbnail
            final mediaUrl = value['url'] ?? value['thumbnail'] ?? '';
            if (mediaUrl.isEmpty) {
              print("⚠️ Skipping story $key - missing media URL");
              return;
            }

            profileStoryDataList.add(
              ProfilePageStoryModel(
                key,
                mediaUrl.toString(),
                value['caption']?.toString() ?? '',
              ),
            );
          });
        } catch (e) {
          print("⚠️ Error processing stories: $e");
        }

        memoriesDataFetched.value = true;
      });
    }
  }
}
