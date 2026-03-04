// // Flutter imports:
// import 'dart:developer';

// // import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:flutter/material.dart';

// // Package imports:
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
// import 'package:fourmoral/screens/videoAndVoiceCall/call_manager.dart';
// import 'package:zego_uikit/zego_uikit.dart';
// import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
// import 'package:flutter_styled_toast/flutter_styled_toast.dart';

// Widget customAvatarBuilder(
//   BuildContext context,
//   Size size,
//   ZegoUIKitUser? user,
//   Map<String, dynamic> extraInfo,
// ) {
//   return CachedNetworkImage(
//     imageUrl: 'https://robohash.org/${user?.id}.png',
//     imageBuilder:
//         (context, imageProvider) => Container(
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
//           ),
//         ),
//     progressIndicatorBuilder:
//         (context, url, downloadProgress) =>
//             CircularProgressIndicator(value: downloadProgress.progress),
//     errorWidget: (context, url, error) {
//       return ZegoAvatar(user: user, avatarSize: size);
//     },
//   );
// }

// // Widget sendCallButton({
// //   required bool isVideoCall,
// //   required TextEditingController inviteeUsersIDTextCtrl,
// //   void Function(String code, String message, List<String>)? onCallFinished,
// // }) {
// //   return ValueListenableBuilder<TextEditingValue>(
// //     valueListenable: inviteeUsersIDTextCtrl,
// //     builder: (context, inviteeUserID, _) {
// //       return FutureBuilder<List<ZegoUIKitUser>>(
// //         future: getInvitesFromTextCtrl(inviteeUsersIDTextCtrl.text.trim()),
// //         builder: (context, snapshot) {
// //           final invitees = snapshot.data ?? [];
// //           return ZegoSendCallInvitationButton(
// //             isVideoCall: isVideoCall,
// //             invitees: invitees,
// //             resourceID: "zego_uikit_call",
// //             iconSize: const Size(40, 40),
// //             buttonSize: const Size(50, 50),
// //             timeoutSeconds: 30,
// //             onPressed: onCallFinished,
// //             onWillPressed: () async {
// //               final callManager = CallManager();
// //               bool isAllowed = false;

// //               await callManager.checkBalanceBeforeCall(
// //                 context: context,
// //                 perMinuteCharge: 10,
// //                 receiverUid: inviteeUsersIDTextCtrl.text.trim(),
// //                 onBalanceSufficient: () {
// //                   // ✅ Balance is sufficient
// //                   isAllowed = true;
// //                 },
// //               );

// //               // 🟢 If balance is sufficient, allow the call
// //               return Future.value(isAllowed);
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // }

// Future<List<ZegoCallUser>> getInvitesFromTextCtrl(String textCtrlText) async {
//   List<ZegoCallUser> invitees = [];

//   try {
//     final snapshot =
//         await FirebaseFirestore.instance
//             .collection('Users')
//             .where('mobileNumber', isEqualTo: textCtrlText)
//             .get();

//     if (snapshot.docs.isNotEmpty) {
//       var profileDataModel = profileDataServices(snapshot.docs.first);

//       var inviteeIDs = textCtrlText.trim().replaceAll('，', '');
//       inviteeIDs.split(",").forEach((inviteeUserID) {
//         if (inviteeUserID.isEmpty) {
//           return;
//         }

//         invitees.add(ZegoCallUser(inviteeUserID, profileDataModel.username));
//       });
//     }
//   } catch (e) {
//     print('Error loading user profile: $e');
//   }

//   return invitees;
// }

// void onSendCallInvitationFinished(
//   String code,
//   String message,
//   List<String> errorInvitees,
//   BuildContext context,
// ) {
//   if (errorInvitees.isNotEmpty) {
//     String userIDs = "";
//     for (int index = 0; index < errorInvitees.length; index++) {
//       if (index >= 5) {
//         userIDs += '... ';
//         break;
//       }

//       var userID = errorInvitees.elementAt(index);
//       userIDs += '$userID ';
//     }
//     if (userIDs.isNotEmpty) {
//       userIDs = userIDs.substring(0, userIDs.length - 1);
//     }

//     var message = 'User doesn\'t exist or is offline: $userIDs';
//     if (code.isNotEmpty) {
//       message += ', code: $code, message:$message';
//     }
//     showToast(message, position: StyledToastPosition.top, context: context);
//   } else if (code.isNotEmpty) {
//     showToast(
//       'code: $code, message:$message',
//       position: StyledToastPosition.top,
//       context: context,
//     );
//   }
// }
