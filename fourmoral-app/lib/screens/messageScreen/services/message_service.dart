// This file includes:
// 1. Reply message UI bubble
// 2. Full AES-RSA encrypted file sender
// 3. Typing indicator trigger logic
// 4. Seen status updater for messages
// 5. Text message encryption via existing addMessage method

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart' as encrypt;
import 'package:basic_utils/basic_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/utils/message_utils.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MessageService {
  static final db = FirebaseDatabase.instance.ref();
  static final notifications = FirebaseDatabase.instance.ref("Notifications");
  DatabaseReference? ref;

  static Future<void> deleteMessageForMe({
    required String userPhone,
    required String otherPhone,
    required String messageKey,
  }) async {
    final path = [userPhone, otherPhone]..sort();
    final chatPath = "${path[0]}-${path[1]}";

    final messageRef = db.child("Messages/$chatPath/Data/$messageKey");

    final snapshot = await messageRef.child("deletedFor").get();
    final existingDeletedFor = snapshot.value as Map<dynamic, dynamic>? ?? {};

    existingDeletedFor[userPhone] = true;

    await messageRef.update({'deletedFor': existingDeletedFor});
  }

  static Future<void> deleteMessageForEveryone({
    required String userPhone,
    required String otherPhone,
    required String messageKey,
  }) async {
    final path = [userPhone, otherPhone]..sort();
    final chatPath = "${path[0]}-${path[1]}";

    log("messageKey $messageKey");
    await db.child("Messages/$chatPath/Data/$messageKey").update({
      'message': 'This message was deleted',
      'fileUrl': '',
      'type': 'deleted',
    });
  }

  static Future<void> updateMessageStatus({
    required String messageId,
    bool? seen,
    bool? delivered,
  }) async {
    final updates = <String, dynamic>{};
    if (seen != null) updates['seen'] = seen;
    if (delivered != null) updates['delivered'] = delivered;

    await FirebaseDatabase.instance
        .ref('Messages')
        .child(messageId)
        .update(updates);
  }

  static Future<void> addMessage(
    String message, {
    String? type,
    String? videoUrl,
    required String profileuserphone,
    required String profileusername,
    required String userphone,
    required String? receiverPublicKey,
    String? contact,
    bool? download,
    Map<String, dynamic>? replyData,
    bool isDeleted = false,
    required Function clearReply,
    required TextEditingController messageController,
    required RxBool needsScroll,
  }) async {
    if (message.trim().isEmpty || receiverPublicKey == null) return;

    // Step 1: Encrypt message with receiver's public key
    final encrypted = await MessageUtils.encryptMessage(
      message.trim(),
      receiverPublicKey,
    );

    final chatPath = [userphone, profileuserphone]..sort();
    final dbPath = "${chatPath[0]}-${chatPath[1]}";

    // Step 2: Generate timestamp
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final messageRef = db.child("Messages/$dbPath/Data").push();

    // Step 3: Construct message object
    final Map<String, dynamic> messageData = {
      "message": encrypted,
      "id": messageRef.ref.key,
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
      "time": timestamp,
    };

    // Step 4: Attach reply data if available
    if (replyData != null && replyData['isReply'] == true) {
      messageData['isReply'] = true;

      messageData['replyTo'] = {
        'id': replyData['replyTo']['id'] ?? '',
        'message':
            replyData['replyTo']['decrypted'] ??
            replyData['replyTo']['message'] ??
            '',
        'type': replyData['replyTo']['type'] ?? 'text',
      };
    }

    // Step 5: Generate consistent chat path by sorting phone numbers

    // Step 6: Save message to Firebase Realtime DB
    await messageRef.set(messageData);

    // Step 7: Update chat summary (for last message preview, etc.)
    await db.child("Messages/$dbPath").update({
      'updatedTime': timestamp,
      'updatedText': encrypted,
    });

    // Step 8: Send notification to receiver's Notifications node
    await notifications.child('$profileuserphone/Notifications/').push().set({
      "type": "message",
      "message": message,
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
      title: profileusername,
      body: message,
      type: 'message',
    );

    // Step 9: Reset UI
    clearReply();
    messageController.clear();
    needsScroll.value = true;
  }

  // Other methods remain the same...

  static Future<void> sendEncryptedFile({
    required File file,
    required String receiverPublicKey,
    required String userPhone,
    required String receiverPhone,
    required String fileType,
    required Function clearReply,
    required RxBool needsScroll,
    String? videoUrl,
    String? contact,
    bool? download,
    Map<String, dynamic>? replyData,
    bool isDeleted = false,
  }) async {
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    final fileBytes = await file.readAsBytes();
    final aesEncrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encryptedBytes = aesEncrypter.encryptBytes(fileBytes, iv: iv).bytes;

    final ref = FirebaseStorage.instance.ref(
      'encrypted/${DateTime.now().millisecondsSinceEpoch}_${file.path.split("/").last}',
    );
    final uploadTask = await ref.putData(Uint8List.fromList(encryptedBytes));
    final fileUrl = await uploadTask.ref.getDownloadURL();

    final rsaKey =
        encrypt.RSAKeyParser().parse(receiverPublicKey) as encrypt.RSAPublicKey;
    final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: rsaKey));
    final encryptedAesKey = rsaEncrypter.encryptBytes(aesKey.bytes).base64;

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final path = [userPhone, receiverPhone]..sort();
    final chatPath = "${path[0]}-${path[1]}";

    final messageRef = db.child("Messages/$chatPath/Data").push();
    log("messageRef ${messageRef.ref.key}");
    final msg = {
      "message": "Encrypted $fileType",
      "id": messageRef.ref.key,
      "sender": userPhone,
      "receiver": receiverPhone,
      "type": fileType,
      "seen": false,
      "time": timestamp,
      "encryptedAesKey": encryptedAesKey,
      "iv": iv.base64,
      "fileUrl": fileUrl,
    };

    if (replyData != null && replyData['isReply'] == true) {
      msg['isReply'] = true;
      msg['replyTo'] = {
        'id': replyData['id'] ?? '',
        'message': replyData['decrypted'] ?? replyData['message'] ?? '',
        'type': replyData['type'] ?? 'text',
      };
    } else {
      msg['isReply'] = false;
    }

    msg['isDeleted'] = isDeleted;
    msg['videoUrl'] = videoUrl ?? '';
    msg['contact'] = contact ?? "";
    msg['documentDownload'] = download ?? false;
    msg['documentCheck'] = false;

    await messageRef.set(msg);
    await db.child("Messages/$chatPath").update({
      'updatedTime': timestamp,
      'updatedText': msg['message'],
    });

    await notifications.child('$receiverPhone/Notifications').push().set({
      "type": "message",
      "message": "Encrypted $fileType",
      "mobileNumber": userPhone,
      "time": DateTime.now().toString(),
    });

    final senderDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(receiverPhone)
            .get();
    final senderFcmToken = senderDoc.data()?['fcmToken'] as String;
    sendNotification(
      userFcmToken: senderFcmToken,
      title: userPhone,
      body: 'Encrypted $fileType',
      type: 'message',
    );

    clearReply();
    needsScroll.value = true;
  }

  static Future<Uint8List> decryptFileMessage({
    required String encryptedAesKey,
    required String ivBase64,
    required String privateKey,
    required String fileUrl,
  }) async {
    final response = await http.get(Uri.parse(fileUrl));
    final encryptedBytes = response.bodyBytes;

    final rsaKey = CryptoUtils.rsaPrivateKeyFromPem(privateKey);
    final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: rsaKey));
    final aesKeyBytes = rsaEncrypter.decryptBytes(
      encrypt.Encrypted.fromBase64(encryptedAesKey),
    );

    final aesEncrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(Uint8List.fromList(aesKeyBytes))),
    );
    final iv = encrypt.IV.fromBase64(ivBase64);

    final decrypted = aesEncrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );

    return Uint8List.fromList(decrypted);
  }

  static Future<void> markAllAsSeen(String user, String peer) async {
    final path = [user, peer]..sort();
    final chatPath = "${path[0]}-${path[1]}";
    final snapshot = await db.child("Messages/$chatPath/Data").get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      for (final entry in data.entries) {
        final msg = entry.value;
        if (msg['receiver'] == user && msg['seen'] == false) {
          await db.child("Messages/$chatPath/Data/${entry.key}/seen").set(true);
        }
      }
    }
  }

  static Future<void> updateTypingStatus({
    required String userPhone,
    required String profilePhone,
    required bool isTyping,
  }) async {
    final chatPath = [userPhone, profilePhone]..sort();
    await db.child("Typing/${chatPath[0]}-${chatPath[1]}/$userPhone").set({
      'typing': isTyping,
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
