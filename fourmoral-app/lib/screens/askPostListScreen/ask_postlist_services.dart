// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/models/ask_postlist_model.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:get/get.dart';

AskPostListModel askPostListServicesDataServices(key, value) {
  AskPostListModel temp;
  String url = '';

  if (value.get('type').toString() == "Photo") {
    url =
        value.data().containsKey('url') && value.get('url').toString() != "null"
            ? value.get('url').toString()
            : "";
  } else {
    url =
        value.data().containsKey('thumbnail') &&
                value.get('thumbnail').toString() != "null"
            ? value.get('thumbnail').toString()
            : "";
  }

  temp = AskPostListModel(
    key.toString() != "null" ? key.toString() : "",
    url,
    value.data().containsKey('username') &&
            value.get('username').toString() != "null"
        ? value.get('username').toString()
        : "",
    value.data().containsKey('caption') &&
            value.get('caption').toString() != "null"
        ? value.get('caption').toString()
        : "",
    value.data().containsKey('type') && value.get('type').toString() != "null"
        ? value.get('type').toString()
        : "",
    value.data().containsKey('dateTime') &&
            value.get('dateTime').toString() != "null"
        ? value.get('dateTime').toString()
        : "",
  );
  return temp;
}

class AskPostListCnt extends GetxController {
  RxBool askPostListDataFetched = false.obs;

  RxList<AskPostListModel> askPostListDataList = <AskPostListModel>[].obs;

  DatabaseReference? refMentorAsk;

  PostModel? postObject;

  getAskData() {
    refMentorAsk?.onValue.listen((event) async {
      askPostListDataList.clear();
      Map? values = event.snapshot.value as Map?;

      if (values != null) {
        values.forEach((key, value) {
          FirebaseFirestore.instance
              .collection('Posts')
              .where('key', isEqualTo: key)
              .snapshots()
              .listen((snapshots) {
                if (snapshots.docs.isNotEmpty) {
                  postObject = postDataServices(snapshots.docs[0], "");
                  askPostListDataList.add(
                    askPostListServicesDataServices(key, snapshots.docs[0]),
                  );
                  askPostListDataList.sort((a, b) {
                    return DateTime.parse(
                      b.dateTime,
                    ).compareTo(DateTime.parse(a.dateTime));
                  });
                  askPostListDataFetched.value = true;
                } else {
                  askPostListDataFetched.value = true;
                }
              });
        });
      } else {
        askPostListDataFetched.value = true;
      }
    });
  }
}
