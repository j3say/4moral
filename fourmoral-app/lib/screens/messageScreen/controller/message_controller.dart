import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/utils/message_utils.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class MessageCnt extends GetxController {
  String? userphone;
  String? userName;
  RxBool isUploading = false.obs;
  RxList messageslist = [].obs;
  RxList numbers = [].obs;
  RxBool fetched = false.obs;
  RxBool needsScroll = false.obs;
  File? thumbnailFile;
  RxBool disappearEnabled = false.obs;
  RxInt disappearDuration = 0.obs;
  DatabaseReference? ref;
  RxList<Map<String, dynamic>> decryptedMessages = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;
  DatabaseReference refNotification = FirebaseDatabase.instance.ref().child(
    'Users/',
  );
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final CustomPopupMenuController controller = CustomPopupMenuController();
  final AudioPlayer audioPlayer = AudioPlayer();
  final AudioRecorder audioRecorder = AudioRecorder();
  RxBool isRecording = false.obs;
  RxBool isPlaying = false.obs;
  RxString recordingPath = ''.obs;
  RxDouble recordingDuration = 0.0.obs;
  RxMap<String, dynamic> replyingToMessage = <String, dynamic>{}.obs;
  String? publicKey;
  String? privateKey;
  String? receiverPublicKey;

  void setReplyingToMessage(Map<String, dynamic> message) {
    replyingToMessage.value = message;
  }

  void clearReply() {
    replyingToMessage.value = {};
  }

  @override
  void onInit() {
    super.onInit();
    audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });
    checkAndDeleteExpiredMessages();
  }

  @override
  void onClose() {
    audioPlayer.dispose();
    audioRecorder.dispose();
    super.onClose();
  }

  Future<void> startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        await audioRecorder.start(
          const RecordConfig(),
          path: await getTempPath(),
        );
        isRecording.value = true;
        recordingDuration.value = 0.0;

        // Update recording duration
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (isRecording.value) {
            recordingDuration.value += 1;
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await audioRecorder.stop();
      if (path != null) {
        recordingPath.value = path;
      }
      isRecording.value = false;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<String> getTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void getMessages({String? profileuserphone}) async {
    ref?.onValue.listen((event) {
      messageslist.clear();
      Map<dynamic, dynamic>? values = event.snapshot.value as Map?;
      if (values != null) {
        values.forEach((key, values) {
          if (key.toString().split("-").contains(userphone) &&
              key.toString().split("-").contains(profileuserphone)) {
            numbers.value = key.toString().split("-");

            // Load disappearing message settings
            disappearEnabled.value = values['disappearEnabled'] == true;
            disappearDuration.value = values['disappearDuration'] ?? 0;

            if (values['Data'] != null) {
              values['Data'].forEach((key1, values1) async {
                try {
                  Map<String, dynamic> map = {
                    "key": key1.toString(),
                    "mainKey": key.toString(),
                    "id": values1["id"]?.toString() ?? '',
                    "message":
                        (values1["message"] != null &&
                                MessageUtils.isBase64(
                                  values1["message"].toString(),
                                ))
                            ? await MessageUtils.decryptMessage(
                              values1["message"].toString(),
                              privateKey ?? "",
                            )
                            : values1["message"]?.toString() ?? '',
                    "time":
                        values1["time"]?.toString() ??
                        DateTime.now().toString(),
                    "type": values1['type']?.toString() ?? 'text',
                    "videoUrl": values1['videoUrl']?.toString(),
                    "contact": values1['contact']?.toString(),
                    "documentDownload": values1['documentDownload'] == true,
                    "documentCheck": values1['documentCheck'] == true,
                    "isReply": values1['isReply'] == true,
                    "isDeleted": values1['isDeleted'] == true,
                    "replyTo":
                        values1['replyTo'] != null
                            ? MessageUtils.convertToTypedMap(values1['replyTo'])
                            : null,
                  };
                  messageslist.add(map);
                } catch (e) {
                  print('Error parsing message: $e');
                }
              });

              messageslist.sort((a, b) {
                return DateTime.parse(
                  b["time"],
                ).compareTo(DateTime.parse(a["time"]));
              });
              fetched.value = true;
            }
          }
        });
      }
    });

    // Start checking for expired messages
    checkAndDeleteExpiredMessages();
  }

  void checkAndDeleteExpiredMessages() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      // Only check if the controller is still active
      if (!GetInstance().isRegistered<MessageCnt>()) {
        timer.cancel();
        return;
      }

      ref?.once().then((DatabaseEvent event) {
        try {
          Map<dynamic, dynamic>? values = event.snapshot.value as Map?;
          if (values != null) {
            values.forEach((key, chatData) {
              // Skip if not a map or doesn't have the required structure
              if (chatData is! Map || chatData['Data'] == null) return;

              final bool isEnabled = chatData['disappearEnabled'] == true;
              final int duration = chatData['disappearDuration'] ?? 0;

              if (isEnabled && duration > 0 && chatData['Data'] is Map) {
                Map<dynamic, dynamic> messagesData = chatData['Data'] as Map;
                messagesData.forEach((messageKey, messageData) {
                  if (messageData is! Map || messageData['time'] == null) {
                    return;
                  }

                  try {
                    final String messageTimeStr =
                        messageData['time'].toString();
                    final DateTime messageTime = DateTime.parse(messageTimeStr);
                    final DateTime expireTime = messageTime.add(
                      Duration(seconds: duration),
                    );

                    if (DateTime.now().isAfter(expireTime) &&
                        messageData['isDeleted'] != true) {
                      ref
                          ?.child(key.toString())
                          .child('Data')
                          .child(messageKey.toString())
                          .update({
                            'isDeleted': true,
                            'message': 'This message has disappeared',
                            'type': 'text',
                            // Clear sensitive content
                            'videoUrl': null,
                            'contact': null,
                            'documentDownload': false,
                            'documentCheck': false,
                          });
                    }
                  } catch (e) {
                    print('Error processing message expiration: $e');
                  }
                });
              }
            });
          }
        } catch (e) {
          print('Error in disappearing messages check: $e');
        }
      });
    });
  }

  Future<void> addMessage(
    String message, {
    String? type,
    String? videoUrl,
    required String profileuserphone,
    String? contact,
    bool? download,
    Map<String, dynamic>? replyData,
    bool isDeleted = false,
  }) async {
    if (message.trim().isEmpty || receiverPublicKey == null) return;

    // Step 1: Encrypt message with receiver's public key
    final encrypted = await MessageUtils.encryptMessage(
      message.trim(),
      receiverPublicKey!,
    );

    // Step 2: Generate timestamp
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final chatPath = [userphone, profileuserphone]..sort();
    final dbPath = "${chatPath[0]}-${chatPath[1]}";

    final messageRef = ref?.child(dbPath).child('Data').push();

    // Step 3: Construct message object
    final Map<String, dynamic> messageData = {
      "message": encrypted,
      "id": messageRef?.key ?? "",
      "sender": userphone,
      "receiver": profileuserphone,
      "type": type ?? "text",
      "videoUrl": videoUrl,
      "contact": contact,
      "documentDownload": download ?? false,
      "documentCheck": false,
      "isReply": false,
      "isDeleted": isDeleted,
      "seen": false,
      "delivered": false,
      "time": timestamp,
      "deletedFor": {"user1": false, "user2": false},
    };

    // Step 4: Attach reply data if available
    if (replyData != null) {
      messageData.addAll(replyData);
    } else if (replyingToMessage.isNotEmpty) {
      messageData['isReply'] = true;
      messageData['replyTo'] = {
        'id': replyingToMessage['id'] ?? '',
        // Store plaintext instead of encrypted reply preview
        'message':
            replyingToMessage['decrypted'] ??
            replyingToMessage['message'] ??
            '',
        'type': replyingToMessage['type'] ?? 'text',
      };
    }

    // Step 5: Generate consistent chat path by sorting phone numbers

    // Step 6: Save message to Firebase Realtime DB
    await messageRef?.set(messageData);

    // Step 7: Update chat summary (for last message preview, etc.)
    await ref?.child(dbPath).update({
      'updatedTime': timestamp,
      'updatedText': encrypted, // or store unencrypted for preview
    });

    // Step 8: Send notification to receiver's Notifications node
    await refNotification.child('$profileuserphone/Notifications/').push().set({
      "type": "message",
      "message": message, // plaintext for preview
      "mobileNumber": userphone,
      "time": DateTime.now().toString(),
    });

    final senderDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(profileuserphone)
            .get();
    final senderFcmToken = senderDoc.data()?['fcmToken'] as String;
    sendNotification(
      userFcmToken: senderFcmToken,
      title: userName ?? (userphone ?? "Message"),
      body: message,
      type: 'message',
    );
    // Step 9: Reset UI
    if (messageData['isReply'] == true) {
      clearReply();
    }
    messageController.clear();
    needsScroll.value = true;
  }

  scrolltobottom() async {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void setDisappearingMessages(int durationInSeconds, String profileuserphone) {
    // Get the chat ID (e.g., "user1-user2")
    final chatId =
        numbers.isNotEmpty
            ? (numbers[0] == userphone
                ? "$userphone-$profileuserphone"
                : "$profileuserphone-$userphone")
            : "$userphone-$profileuserphone";

    // Update the disappearing message settings in the database
    ref?.child(chatId).update({
      'disappearEnabled': durationInSeconds > 0,
      'disappearDuration': durationInSeconds,
    });

    // Update local state
    disappearEnabled.value = durationInSeconds > 0;
    disappearDuration.value = durationInSeconds;
  }

  String getFileName(String url) {
    RegExp regExp = RegExp(r'.+(\/|%2F)(.+)\?.+');
    var matches = regExp.allMatches(url);

    if (matches.isEmpty) return url;

    var match = matches.elementAt(0);
    return Uri.decodeFull(match.group(2)!);
  }

  // Add this method to your MessageCnt class to load the current disappearing message settings
  void loadDisappearingMessageSettings(String profileuserphone) {
    final chatId = "$userphone-$profileuserphone";
    final altChatId = "$profileuserphone-$userphone";

    ref?.child(chatId).once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data['disappearEnabled'] != null) {
        disappearEnabled.value = data['disappearEnabled'] == true;
        disappearDuration.value = data['disappearDuration'] ?? 0;
      } else {
        // Try alternative chat ID format
        ref?.child(altChatId).once().then((DatabaseEvent altEvent) {
          final altData = altEvent.snapshot.value as Map?;
          if (altData != null && altData['disappearEnabled'] != null) {
            disappearEnabled.value = altData['disappearEnabled'] == true;
            disappearDuration.value = altData['disappearDuration'] ?? 0;
          } else {
            // No settings found, use defaults
            disappearEnabled.value = false;
            disappearDuration.value = 0;
          }
        });
      }
    });
  }

  static Future<void> sendNotification({
    required String userFcmToken,
    required String title,
    required String body,
    required String type,
  }) async {
    final String serverToken = await getAccessToken();

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/moral-9f5c7/messages:send",
    );

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $serverToken",
    };

    final bodyData = {
      "message": {
        "token": userFcmToken,
        "notification": {"title": title, "body": body},
        "data": {"type": type},
      },
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyData),
      );
      if (response.statusCode == 200) {
        print("✅ Notification sent successfully!");
      } else {
        print("❌ Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error sending notification: $e");
    }
  }
}

Future<String> getAccessToken() async {
  final serviceAccountJson = {
    "type": "service_account",
    "project_id": "moral-9f5c7",
    "private_key_id": "8f07cce82cc5f0b01c7e2bc7f309f98ebfe0c581",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC0eQdmSFMPHQas\nipCe83s8LoNDN0iAxtsk5/kNiKH6GjO9nMgF+YUTKDtP1XfxBIfJtgPQtTjV5FPW\n4HgiiM78x06GHiYTwmKNZZnr8YgIc+M7CdYIP+Nlad3p7TdiA9g4czjHWWseTvl3\nT+vbCyzxvx2MtOHDSVxzQISyF1bmpUWkpdaqs1gYCtO69x51tt67SdMAJ1P4XOhW\ntTvREDfQ6sJqJDinGOjg0kNFWXtjnGhOwE7fs5u/dCbZrkawh6ZVx9i7cQn2OthU\nXeXCfQ0CP1VpaBzgpceZVYCiLe7ck4M+OG2NX8vLORL1haq90ySUhBZTJ6OSCT+W\nnbDz5XE5AgMBAAECggEAWRzj7vjqbm2GNJ9tHteaM9LBxOhg2BmY7wXOQAUF+jGC\n9+8ZA348XAPDGb4N7ggvJoZGJwG88Ty/uzv2hhLopf+iAe6UHbCfqjMPiGYopgfX\nHXlTYpptZc+bIJ2d+bttQh5+3EyGbJ5RZz0i+HNxu2MDq81LJvsr98rVWvzUT6la\nzqjzEmPKLwsiW8AvX1e498XRceWoczh27VNwA9eWh+EHWvGWHNQUp8EyFPFpQ5JU\n0rbjkKkYQqi4d+Vm8Oxr0dqGlQ8Z/m50mxQvnaxhsEpjQXC6Wmkm2GxDj7a82EQF\nZmYrn6ExyqWc3gqXwvP7dAdKRn0Py6ezh+kNKhiKWwKBgQDX4uTba/HNIPkM9/dP\nCpxTosqxViSvzb06zWg/ptmPuaX1/NtapVTuxTZfsH0auIK78oGp4owBJAitwSGU\nnmNYU7qT7l3pI96akR5tZz6ASbSWTUvotu1+bYu9vHk2zoh4Bg6m6zaPnQFpRnyh\nQ1w/WNIYrpCUdjqYQTWuHBaPRwKBgQDWAZzEfcNowoHNmwRv5vasRyURgSJNRDZP\nzEuJ4M/EyrTv9ni7Rlz6O1UuzxO6eAXfiRLwScc47O8EoIbZye+1Ep5RtgFRArVD\nGCcwq01tXFwflpozs/pvP911o8tIxsVpNIkWBEj8a4waetLlgt4pLPmkJBhPBNaJ\nDcjU7lk7fwKBgB3cc31qQ+r0uZ4ymlGjjRYAeXroCHEMyzTb/qR3RrabnjoVPJ4g\nKkxQmQHJXrSYevTWSVsfS/BIdK7b/PIaqnEoO7GEkhbScFL+6a+GTV3fVAxKKsrI\nqrcHHgIjlLyg+r1nURWDiWt58x0Fs+12bMcSWRUy6Cqw48/1jSBFIFW3AoGAHtUI\nov6DgrpTPS4SS5T5AQUXABicuokTUhfa4jhzdqTFwLS/3CtdBeg6c43+B6V3Iyd6\nhQf8HeV04jPGeeYwFORjzt3r/qHnP41hSA/GDfV6iEqIWN6bPB/1Zhd9GDUbB/c7\nsOJZKZTNEJuVet+J5mDGbrGMlwXZatGDl7nnPT0CgYAFk1Q5kg9w+vui7RKuw8RJ\ngg0CxBXTaYcmKP5gnYW7r6QklwTIsNrfBFPypc6iymVwXGIV2Pe7KjMvt9O5jcnA\n8PwFARkcTaP+vliUQe+b+kQkAJYVz3SArjimtZNHyWa1n8Iq52UUJxKZQzWbAxQV\nBtw9YYQKHdXH9qmSoQ25vg==\n-----END PRIVATE KEY-----\n",
    "client_email":
        "firebase-adminsdk-j0vq2@moral-9f5c7.iam.gserviceaccount.com",
    "client_id": "112464179821295423078",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url":
        "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-j0vq2%40moral-9f5c7.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com",
  };

  List<String> scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/firebase.messaging",
  ];
  http.Client client = await auth.clientViaServiceAccount(
    auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
    scopes,
  );
  auth.AccessCredentials credentials = await auth
      .obtainAccessCredentialsViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
        scopes,
        client,
      );
  client.close();
  return credentials.accessToken.data;
}

//
//   Future<void> sendFCMNotification({
//     required String receiverFcmToken,
//     required String title,
//     required String body,
//     required String type, // post, story, or chat
//     // required String requestId,
//     // Map<String, String>? data,
//   }) async {
//     try {
//       final url = 'https://fcm.googleapis.com/fcm/send';
//       final headers = {
//         'Content-Type': 'application/json',
//         'Authorization': 'key=$fcmServerKey',
//       };
//       final payload = {
//         'to': receiverFcmToken,
//         'notification': {'title': title, 'body': body},
//         'data': {'type': type},
//       };
//
//       final response = await http
//           .post(Uri.parse(url), headers: headers, body: jsonEncode(payload))
//           .timeout(Duration(seconds: 10));
//
//       if (response.statusCode == 200) {
//         debugPrint("Notification sent successfully: ${response.body}");
//       } else {
//         debugPrint("Failed to send notification: ${response.body}");
//         // flutterShowToast("Failed to send notification");
//       }
//     } catch (e) {
//       debugPrint("Error sending notification: $e");
//       flutterShowToast("Error sending notification: $e");
//     }
//   }
// }
