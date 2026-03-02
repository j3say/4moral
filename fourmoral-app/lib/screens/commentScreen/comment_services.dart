import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

import '../../models/comment_model.dart';

CommentModel commentServicesDataServices(value) {
  CommentModel temp;
  temp = CommentModel(
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    '${value.get('mobileNumber')}'.toString() != "null"
        ? '${value.get('mobileNumber')}'.toString()
        : "",
    '${value.get('dateTime')}'.toString() != "null"
        ? '${value.get('dateTime')}'.toString()
        : "",
    '${value.get('comment')}'.toString() != "null"
        ? '${value.get('comment')}'.toString()
        : "",
  );
  return temp;
}

class CommentScreenCnt extends GetxController {
  final ScrollController scrollController = ScrollController();

  RxBool commentDataFetched = false.obs;

  RxList<CommentModel> commentDataList = <CommentModel>[].obs;

  final TextEditingController messageController = TextEditingController();

  CollectionReference collectionPostReference =
      FirebaseFirestore.instance.collection('Posts');

  getCommentData({String? postId}) {
    commentDataList.clear();

    collectionPostReference.where('key', isEqualTo: postId).get().then((value) {
      value.docs[0].reference
          .collection('Comments')
          .orderBy('dateTime', descending: true)
          .limit(400)
          .snapshots()
          .listen((snapshots) {
        commentDataList.clear();
        if (snapshots.docs.toString() != "[]") {
          for (var i = 0; i < snapshots.docs.length; i++) {
            commentDataList.add(commentServicesDataServices(snapshots.docs[i]));
          }
        }
        commentDataFetched.value = true;
      });
    });
  }

  addMessage({String? comment, String? postId}) {
    collectionPostReference.where('key', isEqualTo: postId).get().then((value) {
      value.docs[0].reference.collection('Comments').add({
        'comment': '$comment',
        'username': profileDataModel?.username,
        'profilePicture': profileDataModel?.profilePicture,
        'mobileNumber': profileDataModel?.mobileNumber,
        'dateTime': DateTime.now().toString(),
      });

      FirebaseDatabase.instance
          .ref()
          .child('Users/')
          .child('${value.docs[0].get('mobileNumber')}/Notifications/')
          .push()
          .set({
        "type": "postComment",
        "mobileNumber": profileDataModel?.mobileNumber,
        "comment": comment,
        "time": DateTime.now().toString(),
        "url": value.docs[0].get('url'),
        "postId": postId,
        "profilePicture": profileDataModel?.profilePicture,
        "username": profileDataModel?.username,
      });
    });
  }

  scrolltobottom() async {
    if (scrollController.hasClients) {
      scrollController.animateTo(scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.fastOutSlowIn);
    }
  }
}
