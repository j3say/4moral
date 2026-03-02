import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/group_info_model.dart';
import 'package:get/get.dart';

GroupModel groupServices(key, value) {
  GroupModel temp;
  temp = GroupModel(
      '${value.get('username')}'.toString() != "null"
          ? '${value.get('username')}'.toString()
          : "",
      '${value.get('profilePicture')}'.toString() != "null"
          ? '${value.get('profilePicture')}'.toString()
          : "",
      key.toString());
  return temp;
}

class GroupInformationCnt extends GetxController {
  RxBool groupInfoFetched = false.obs;

  RxList<GroupModel> groupInfo = <GroupModel>[].obs;

  getGroupData(List? information) {
    String temp = information?[2];

    List tempList = temp.split("--");

    tempList.removeLast();

    for (var i = 0; i < tempList.length; i++) {
      FirebaseFirestore.instance
          .collection('Users')
          .where('mobileNumber', isEqualTo: tempList[i].toString())
          .snapshots()
          .listen((snapshots) {
        if (snapshots.docs.isNotEmpty) {
          groupInfo
              .add(groupServices(tempList[i].toString(), snapshots.docs[0]));
          groupInfoFetched.value = true;
        }
      });
    }

    groupInfoFetched.value = true;
  }
}
