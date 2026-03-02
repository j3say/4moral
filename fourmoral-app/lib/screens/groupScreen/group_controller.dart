import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

class GroupScreenCnt extends GetxController {
  RxBool groupNamesFetched = false.obs;

  RxList groupNames = [].obs;

  DatabaseReference? refGroups;

  getGroupData() {
    refGroups?.get().then((value) {
      Map<dynamic, dynamic>? values = value.value as Map?;

      if (values != null) {
        values.forEach((key, value) {
          if (value['members']
              .toString()
              .contains(profileDataModel?.mobileNumber ?? "")) {
            Map<dynamic, dynamic> map = {
              'groupName': value['groupName'],
              'groupKey': key,
              'dateTime': value['dateTime'],
              'updatedText': value['updatedText'],
              'updatedTime': value['updatedTime'],
              'members': value['members'],
            };
            groupNames.add(map);

            groupNames.sort((a, b) {
              return DateTime.parse(b["updatedTime"])
                  .compareTo(DateTime.parse(a["updatedTime"]));
            });
          }
        });
      }
      groupNamesFetched.value = true;
    });
  }
}
