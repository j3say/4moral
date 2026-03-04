// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:fourmoral/models/blocked_users_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

BlockedUsersModel blockedServices(key, value) {
  BlockedUsersModel temp;
  temp = BlockedUsersModel(
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    key.toString() != "null" ? key.toString() : "",
  );
  return temp;
}

class BlockUserCnt extends GetxController {
  RxBool blockedDataFetched = false.obs;

  RxList<BlockedUsersModel> blockedDataList = <BlockedUsersModel>[].obs;

  CollectionReference collectionUserReference =
      FirebaseFirestore.instance.collection('Users');

  getBlockUsersData() {
    String blockedDataString = profileDataModel!.block;

    List<String> blockedDataListTemp = blockedDataString.split("//");

    blockedDataListTemp.removeLast();

    for (var i = 0; i < blockedDataListTemp.length; i++) {
      FirebaseFirestore.instance
          .collection('Users')
          .where('mobileNumber', isEqualTo: blockedDataListTemp[i].toString())
          .snapshots()
          .listen((snapshots) {
        blockedDataList.add(blockedServices(
            blockedDataListTemp[i].toString(), snapshots.docs[0]));
        blockedDataFetched.value = true;
      });
    }
    blockedDataFetched.value = true;
  }
}
