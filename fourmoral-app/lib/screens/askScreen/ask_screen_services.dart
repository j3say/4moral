import 'dart:developer';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

import '../../models/ask_model.dart';

AskModel askServicesDataServices(value) {
  AskModel temp;
  temp = AskModel(
    '${value['username']}'.toString() != "null"
        ? '${value['username']}'.toString()
        : "",
    '${value['profilePicture']}'.toString() != "null"
        ? '${value['profilePicture']}'.toString()
        : "",
    '${value['mobileNumber']}'.toString() != "null"
        ? '${value['mobileNumber']}'.toString()
        : "",
    '${value['dateTime']}'.toString() != "null"
        ? '${value['dateTime']}'.toString()
        : "",
    '${value['comment']}'.toString() != "null"
        ? '${value['comment']}'.toString()
        : "",
  );
  return temp;
}

class AskScreenCnt extends GetxController {
  final ScrollController scrollController = ScrollController();

  RxBool askDataFetched = false.obs;

  RxList<AskModel> askDataList = <AskModel>[].obs;

  final TextEditingController messageController = TextEditingController();

  DatabaseReference? refAsk;

  getAskData() {
    log("refAsk ${refAsk?.ref}");
    refAsk?.orderByChild('dateTime').onValue.listen((event) {
      askDataList.clear();
      if (event.snapshot.value != null) {
        Map? values = event.snapshot.value as Map?;

        log("askDataList $values");
        values?.forEach((key, value) {
          askDataList.add(askServicesDataServices(value));
        });

        askDataList.sort((a, b) {
          return DateTime.parse(
            b.dateTime,
          ).compareTo(DateTime.parse(a.dateTime));
        });

        askDataFetched.value = true;
      } else {
        askDataFetched.value = true;
      }
    });
  }

  addMessage({
    String? comment,
    required PostModel? postObject,
    required String? phone,
  }) {
    refAsk?.push().set({
      'username': profileDataModel?.username,
      'profilePicture': profileDataModel?.profilePicture,
      'mobileNumber': profileDataModel?.mobileNumber,
      'dateTime': DateTime.now().toString(),
      'comment': comment,
    });

    if (postObject?.mobileNumber != profileDataModel?.mobileNumber) {
      FirebaseDatabase.instance
          .ref()
          .child('Users/')
          .child('$phone/Notifications/')
          .push()
          .set({
            "type": "postAsk",
            "mobileNumber": profileDataModel?.mobileNumber,
            "comment": comment,
            "time": DateTime.now().toString(),
            "url": postObject!.urls.isNotEmpty ? postObject.urls[0] : '',
            "postId": postObject.key,
            "profilePicture": profileDataModel?.profilePicture,
            "username": profileDataModel?.username,
          });
    } else {
      FirebaseDatabase.instance
          .ref()
          .child('Users/')
          .child('${postObject?.mobileNumber}/Notifications/')
          .push()
          .set({
            "type": "postAskReply",
            "mobileNumber": profileDataModel?.mobileNumber,
            "comment": comment,
            "time": DateTime.now().toString(),
            "url": postObject!.urls.isNotEmpty ? postObject.urls[0] : '',
            "postId": postObject.key,
            "profilePicture": profileDataModel?.profilePicture,
            "username": profileDataModel?.username,
          });
    }
  }

  scrolltobottom() async {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
      );
    }
  }
}
