// lib/screens/groupScreen/group_controller.dart
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/services/api_service.dart';
import 'package:get/get.dart';

class GroupScreenCnt extends GetxController {
  RxBool groupNamesFetched = false.obs;
  RxList groupNames = [].obs;


  Future<void> getGroupData() async {
    try {
      final ApiService api = ApiService();
      List<Map<dynamic, dynamic>> apiData = await api.getGroups();
      
      groupNames.clear();

      for (var value in apiData) {
        if (value['members'].toString().contains(profileDataModel?.mobileNumber ?? "")) {
          Map<dynamic, dynamic> map = {
            'groupName': value['groupName'],
            'groupKey': value['groupKey'],
            'dateTime': value['dateTime'],
            'updatedText': value['updatedText'],
            'updatedTime': value['updatedTime'],
            'members': value['members'],
          };
          groupNames.add(map);
        }
      }

      groupNames.sort((a, b) {
        return DateTime.parse(b["updatedTime"])
            .compareTo(DateTime.parse(a["updatedTime"]));
      });

      groupNamesFetched.value = true;
    } catch (e) {
      print("Error fetching groups: $e");
      groupNamesFetched.value = true;
    }
  }
}