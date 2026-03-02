import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

import '../../models/following_model.dart';

FollowingModel followingServices(key, value) {
  FollowingModel temp;
  temp = FollowingModel(
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    key.toString() != "null" ? key.toString() : "",
    '${value.get('uniqueId')}'.toString() != "null"
        ? '${value.get('uniqueId')}'.toString()
        : "",
  );
  return temp;
}

class FollowingCnt extends GetxController {
  RxBool followingDataFetched = false.obs;

  RxList<FollowingModel> followingDataList = <FollowingModel>[].obs;

  getFollowingData() {
    String followingDataString = profileDataModel?.followMentors ?? "";

    List<String> followingDataListTemp = followingDataString.split("//");

    followingDataListTemp.removeLast();

    for (var i = 0; i < followingDataListTemp.length; i++) {
      FirebaseFirestore.instance
          .collection('Users')
          .where('mobileNumber', isEqualTo: followingDataListTemp[i].toString())
          .snapshots()
          .listen((snapshots) {
        followingDataList.add(followingServices(
            followingDataListTemp[i].toString(), snapshots.docs[0]));
        followingDataFetched.value = true;
      });
    }
    followingDataFetched.value = true;
  }
}
