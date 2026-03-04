// import '../../models/chat_model.dart';

// ChatModel chatServicesDataServices(value) {
//   ChatModel temp;
//   temp = ChatModel(
//     '${value.get('message')}'.toString() != "null"
//         ? '${value.get('message')}'.toString()
//         : "",
//     '${value.get('type')}'.toString() != "null"
//         ? '${value.get('type')}'.toString()
//         : "",
//     '${value.get('dateTime')}'.toString() != "null"
//         ? '${value.get('dateTime')}'.toString()
//         : "",
//   );
//   return temp;
// }

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

class ChatScreenCnt extends GetxController {
  RxList list = [].obs;
  RxList list1 = [].obs;
  RxList list2 = [].obs;
  RxBool fetched = false.obs;
  DatabaseReference? ref;
  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');

  void getList() async {
    ref?.child('Messages/').once().then((DatabaseEvent snapshot) {
      list.clear();
      list1.clear();
      String? listuserphone;
      Map<dynamic, dynamic>? values = snapshot.snapshot.value as Map?;

      if (values != null) {
        values.forEach((key, values) {
          if (key
              .toString()
              .split("-")
              .contains(profileDataModel?.mobileNumber)) {
            var numbers = key.toString().split("-");
            if (numbers[0] == profileDataModel?.mobileNumber) {
              listuserphone = numbers[1];
            } else if (numbers[1] == profileDataModel?.mobileNumber) {
              listuserphone = numbers[0];
            }

            list.add({
              'userphone': listuserphone,
              'updatedTime': values['updatedTime'],
              'updatedText': values['updatedText'],
            });
          }
        });
      }
      for (var i = 0; i < list.length; i++) {
        collectionUserReference
            .where('mobileNumber', isEqualTo: list[i]['userphone'])
            .snapshots()
            .listen((snapshots) {
              if (snapshots.docs.isNotEmpty) {
                Map<dynamic, dynamic> map = {
                  "listname": snapshots.docs[0].get('username'),
                  "listimg": snapshots.docs[0].get('profilePicture'),
                  "updatedTime": "${list[i]['updatedTime']}",
                  "updatedText": "${list[i]['updatedText']}",
                  "listphone": "${list[i]['userphone']}",
                };
                if (contactsString.contains(list[i]['userphone'])) {
                  list1.add(map);
                } else {
                  list2.add(map);
                }
                list1.sort(
                  (a, b) => b['updatedTime'].compareTo(a['updatedTime']),
                );
                list2.sort(
                  (a, b) => b['updatedTime'].compareTo(a['updatedTime']),
                );
              }
              fetched.value = true;
            });
      }

      fetched.value = true;
    });
  }
}
