// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class GroupMessageScreenCnt extends GetxController {
  // Reactive variables
  final RxBool groupDataFetched = false.obs;
  final RxList<Map<String, dynamic>> groupDataText =
      <Map<String, dynamic>>[].obs;
  final RxBool needsScroll = false.obs;
  final RxString admin = ''.obs;
  final RxString groupName = ''.obs;

  // Controllers
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // References
  DatabaseReference? refGroups;
  final DatabaseReference ref = FirebaseDatabase.instance.ref().child('groups');

  // Current user's phone number
  String get profileUserPhone => profileDataModel?.mobileNumber ?? "";

  // @override
  // void onInit() {
  //   super.onInit();
  //   refGroups = FirebaseDatabase.instance.ref().child('Groups');
  // }

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> getGroupData({required String groupKey}) async {
    try {
      groupDataFetched.value = false;

      final subscription = refGroups?.child(groupKey).onValue.listen((
        DatabaseEvent snapshot,
      ) {
        _processGroupData(snapshot);
      });

      // Handle potential memory leaks
      ever(groupDataFetched, (_) => subscription?.cancel());
    } catch (e) {
      Get.snackbar('Error', 'Failed to load group data: ${e.toString()}');
      groupDataFetched.value = true;
    }
  }

  void _processGroupData(DatabaseEvent snapshot) {
    groupDataText.clear();

    final values = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (values == null) {
      groupDataFetched.value = true;
      return;
    }

    groupName.value = values['groupName']?.toString() ?? '';
    admin.value = values['admin']?.toString() ?? '';

    final groupData = values['data'] as Map<dynamic, dynamic>?;
    if (groupData != null) {
      groupData.forEach((key, value) {
        final messageData = value as Map<dynamic, dynamic>;
        groupDataText.add({
          'messageKey': key.toString(),
          'username': messageData['username']?.toString() ?? 'Unknown',
          'userMobilenumber': messageData['userMobilenumber']?.toString() ?? '',
          'userProfilePicture':
              messageData['userProfilePicture']?.toString() ?? '',
          'dateTime':
              messageData['dateTime']?.toString() ?? DateTime.now().toString(),
          'message': messageData['message']?.toString() ?? '',
        });
      });

      // Sort messages by date (newest first)
      groupDataText.sort((a, b) {
        return DateTime.parse(
          b["dateTime"],
        ).compareTo(DateTime.parse(a["dateTime"]));
      });
    }

    groupDataFetched.value = true;
  }

  Future<void> addMessage({
    required String message,
    required String groupKey,
  }) async {
    try {
      if (message.trim().isEmpty) return;

      final newMessage = {
        'username': profileDataModel?.username ?? 'Unknown',
        'userMobilenumber': profileUserPhone,
        'userProfilePicture': profileDataModel?.profilePicture ?? '',
        'dateTime': DateTime.now().toString(),
        'message': message.trim(),
      };

      // Add message to group data
      await refGroups?.child(groupKey).child('data').push().set(newMessage);

      // Update group metadata
      await refGroups?.child(groupKey).update({
        'updatedText': message.trim(),
        'updatedTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      messageController.clear();
      scrolltobottom();
    } catch (e) {
      Get.snackbar('Error', 'Failed to send message: ${e.toString()}');
    }
  }

  Future<void> deleteMessage({
    required String groupKey,
    required String messageKey,
  }) async {
    try {
      await ref.child(groupKey).child('data').child(messageKey).remove();
      getGroupData(groupKey: groupKey); // Refresh messages
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete message: ${e.toString()}');
    }
  }

  Future<void> scrolltobottom() async {
    if (scrollController.hasClients) {
      await scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}
