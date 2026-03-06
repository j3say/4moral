// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/main.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_controller.dart';
import 'package:fourmoral/screens/homePageScreen/home_controller.dart';
import 'package:fourmoral/screens/logInScreen/log_in_screen.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:get/get.dart';
import '../models/contacts_model.dart';
import '../models/notification_model.dart';
import '../models/search_users_model.dart';
import '../models/story_model.dart';
import '../models/user_list_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_profile_post_model.dart';
import '../models/user_profile_story_model.dart';
import '../screens/infoGatheringScreen/info_gathering_screen.dart';
import '../screens/navigationBar/navigation_bar.dart';
import '../widgets/flutter_toast.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final homeCnt = Get.put(HomeCnt());
  final exploreCnt = Get.put(ExploreCnt());
  final profileCnt = Get.put(ProfileController());
  final _storage = GetStorage();

  signOut(BuildContext context) async {
    homeCnt.profileDataFetched.value = false;
    profileDataModel = null;
    globalProfile = null;

    homeCnt.contactsDataFetched.value = false;
    notificationFetched = false;
    notificationList.clear();

    homeCnt.postDataFetched.value = false;

    homeCnt.postDataList.clear();
    profileCnt.userProfilePostDataFetched.value = false;
    homeCnt.storyDataFetched.value = false;
    profileCnt.memoriesDataFetched.value = false;
    homepageStoryDataList.clear();
    profileCnt.profileStoryDataList.clear();
    valuesStory = null;
    profileCnt.profileValuesStory = null;
    profileCnt.storyDataList.clear();
    userWatchLaterDataFetched = false;
    userLikePostDataFetched = false;
    userList.clear();
    userSavedPostDataFetched = false;
    searchUserDataFetched = false;
    exploreCnt.explorePageDataFetched.value = false;
    searchUserDataList.clear();
    homeCnt.realPostDataList.clear();
    exploreCnt.explorePostDataList.clear();
    profileCnt.userProfilePostDataPhotoList.clear();
    userProfilePostDataVideoList.clear();
    userLikePostDataPhotoList.clear();
    userLikePostDataVideoList.clear();
    userSavedPostDataPhotoList.clear();
    userSavedPostDataVideoList.clear();
    userWatchLaterDataPhotoList.clear();
    userWatchLaterDataVideoList.clear();
    userProfileStoryDataFetched = false;
    userProfileStoryDataList.clear();

    final phone = AppPreference().getString(PreferencesKey.userPhoneNumber);
    if (phone.isNotEmpty) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .where('mobileNumber', isEqualTo: phone)
                .limit(1)
                .get();

        if (userDoc.docs.isNotEmpty) {
          await userDoc.docs.first.reference.update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      }
    }

    if (!kIsWeb) {
      final phone = AppPreference().getString(PreferencesKey.userPhoneNumber);
      if (phone.isNotEmpty) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            // Firestore logic for mobile only
            await FirebaseFirestore.instance
                .collection('Users')
                .where('mobileNumber', isEqualTo: phone)
                .limit(1)
                .get()
                .then((userDoc) async {
                  if (userDoc.docs.isNotEmpty) {
                    await userDoc.docs.first.reference.update({
                      'fcmTokens': FieldValue.arrayRemove([token]),
                    });
                  }
                });
          }
        } catch (e) {
          debugPrint("FCM cleanup skipped: $e");
        }
      }
    }

    _storage.remove('jwt_token'); 
    await AppPreference().setBool(PreferencesKey.loggedIn, false);
    await AppPreference().setString(PreferencesKey.userPhoneNumber, '');

    // FirebaseAuth.instance.signOut();
    Get.offAll(() => const LoginScreen());

    // await AppPreference().setBool(PreferencesKey.loggedIn, false);
    // await AppPreference().setBool(PreferencesKey.infoGathered, false);
    // await AppPreference().setString(PreferencesKey.userPhoneNumber, '');
    flutterShowToast('Signed Out Successfully');
  }

  // Future<String?> _getValidFCMToken() async {
  //   try {
  //     final token = await FirebaseMessaging.instance.getToken();
  //     if (token == null || token.isEmpty || !_isValidFcmToken(token)) {
  //       debugPrint('Invalid FCM token received: $token');
  //       return null;
  //     }
  //     return token;
  //   } catch (e) {
  //     debugPrint('Error getting FCM token: $e');
  //     return null;
  //   }
  // }

  // bool _isValidFcmToken(String token) {
  //   // Basic FCM token validation
  //   return token.length > 30 && token.contains(':') && !token.contains(' ');
  // }

  // Future signIn(
  //   AuthCredential authCreds,
  //   String phone,
  //   BuildContext context,
  // ) async {
  //   try {
  //     final UserCredential userCredential = await FirebaseAuth.instance
  //         .signInWithCredential(authCreds);

  //     // Get and validate FCM token
  //     final String? fcmToken = await _getValidFCMToken();

  //     CollectionReference collectionUserReference = FirebaseFirestore.instance
  //         .collection('Users');

  //     final query =
  //         await collectionUserReference
  //             .where('mobileNumber', isEqualTo: phone)
  //             .limit(1)
  //             .get();

  //     if (query.docs.isEmpty) {
  //       // New user - create document
  //       await collectionUserReference.add({
  //         'mobileNumber': phone,
  //         'infoGathered': false,
  //         'notificationEnabled': true,
  //         'fcmTokens': fcmToken != null ? [fcmToken] : [],
  //         'createdAt': FieldValue.serverTimestamp(),
  //         'uid': userCredential.user?.uid,
  //         'username': '', // Initialize empty username
  //       });

  //       await _handleNewUser(phone, context);
  //     } else {
  //       // Existing user - update document
  //       final userDoc = query.docs[0];
  //       final updates = {
  //         'lastLogin': FieldValue.serverTimestamp(),
  //         'uid': userCredential.user?.uid,
  //       };

  //       AppPreference().setString(
  //         cacheUserIDKey,
  //         userCredential.user?.uid ?? "",
  //       );

  //       if (fcmToken != null) {
  //         final existingTokens = List<String>.from(userDoc['fcmTokens'] ?? []);
  //         updates['fcmTokens'] = existingTokens;

  //         if (!existingTokens.contains(fcmToken)) {
  //           updates['fcmTokens'] = FieldValue.arrayUnion([fcmToken]);
  //         }
  //       }

  //       // Initialize notificationEnabled if missing
  //       if (!userDoc.exists || userDoc['notificationEnabled'] == null) {
  //         updates['notificationEnabled'] = true;
  //       }

  //       await collectionUserReference.doc(userDoc.id).update(updates);

  //       await _handleExistingUser(userDoc, phone, context);
  //     }
  //   } catch (e) {
  //     Navigator.pop(context);
  //     flutterShowToast("Invalid Verification Code");
  //     debugPrint('SignIn error: $e');
  //   }
  // }

  Future<void> _handleNewUser(String phone, BuildContext context) async {
    await AppPreference().setBool(PreferencesKey.loggedIn, true);
    await AppPreference().setBool(PreferencesKey.infoGathered, false);
    await AppPreference().setString(PreferencesKey.userPhoneNumber, phone);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoGatheringScreen(userPhoneNumber: phone),
      ),
    );
  }

  Future<void> _handleExistingUser(
    QueryDocumentSnapshot userDoc,
    String phone,
    BuildContext context,
  ) async {
    if (userDoc.get('infoGathered')) {
      // Info Gathered
      await AppPreference().setBool(PreferencesKey.loggedIn, true);
      await AppPreference().setBool(PreferencesKey.infoGathered, true);
      await AppPreference().setString(PreferencesKey.userPhoneNumber, phone);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NavigationBarCustom(userPhoneNumber: phone),
        ),
      );
    } else {
      await AppPreference().setBool(PreferencesKey.loggedIn, true);
      await AppPreference().setBool(PreferencesKey.infoGathered, false);
      await AppPreference().setString(PreferencesKey.userPhoneNumber, phone);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InfoGatheringScreen(userPhoneNumber: phone),
        ),
      );
    }
  }

  // signInWithOTP(smsCode, verId, phone, context) {
  //   AuthCredential authCreds = PhoneAuthProvider.credential(
  //     verificationId: verId,
  //     smsCode: smsCode,
  //   );
  //   signIn(authCreds, phone, context);
  // }
}
