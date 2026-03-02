import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/notificationScreen/notification_helper.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

import '../models/prayer.dart';

class PrayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseStorage get storage => _storage;
  FirebaseFirestore get firestore => _firestore;

  String get _userId => _auth.currentUser!.uid;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initializeNotifications() async {
    await _messaging.requestPermission();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    // You can show a local notification here using flutter_local_notifications
  }

  Future<bool> getNotificationStatus() async {
    try {
      final doc = await _firestore.collection('Users').doc(_userId).get();
      if (!doc.exists) {
        // Initialize with default value if document doesn't exist
        await setNotificationStatus(true);
        return true;
      }
      return doc['notificationEnabled'] as bool? ?? true;
    } catch (e) {
      print('Error getting notification status: $e');
      return true; // Default to enabled if error occurs
    }
  }

  Future<void> setNotificationStatus(bool enabled) async {
    try {
      await _firestore.collection('Users').doc(_userId).update({
        'notificationEnabled': enabled,
        'lastNotificationPrefUpdate': FieldValue.serverTimestamp(),
      });
      print('Notification status updated to: $enabled');
    } catch (e) {
      print('Error updating notification status: $e');
      // Create document if it doesn't exist
      if (e is FirebaseException && e.code == 'not-found') {
        await _firestore.collection('Users').doc(_userId).set({
          'notificationEnabled': enabled,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        rethrow;
      }
    }
  }

  Future<void> togglePrayerNotification(
    String prayerId,
    bool enable,
    String? username,
  ) async {
    final userId = _auth.currentUser!.uid;

    final userDoc =
        await _firestore
            .collection('Users')
            .where('username', isEqualTo: username)
            .get();
    final fetchedUsername =
        userDoc.docs.isNotEmpty
            ? userDoc.docs.first['username'] as String?
            : null;

    if (fetchedUsername == null) {
      throw Exception('User does not have a username');
    }

    await _firestore.collection('prayers').doc(prayerId).update({
      'subscribers':
          enable
              ? FieldValue.arrayUnion([fetchedUsername])
              : FieldValue.arrayRemove([fetchedUsername]),
    });

    if (enable) {
      print('enable $username');
      try {
        final prayerDoc =
            await _firestore.collection('prayers').doc(prayerId).get();

        if (prayerDoc.exists) {
          final prayer = Prayer.fromDocument(prayerDoc);

          // Send notification only to the subscribing user
          await _sendPrayerNotification(
            title: 'Subscription Confirmed',
            body: 'You will receive updates for: ${prayer.title}',
            userId: username, // Send only to this user
            prayerId: prayerId,
          );
        }
      } catch (e) {
        print('Error sending subscription notification: $e');
      }
    }
  }

  // Create a new prayer
  Future<Prayer> createPrayer({
    required String title,
    required String username,
    required File audioFile,
  }) async {
    // 1. Upload audio file to storage
    final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref().child('prayers/$fileName');
    final uploadTask = storageRef.putFile(audioFile);
    final snapshot = await uploadTask;
    final audioUrl = await snapshot.ref.getDownloadURL();

    // 2. Calculate expiration time (24 hours from now)
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    // 3. Create prayer document
    final docRef = await _firestore.collection('prayers').add({
      'title': title,
      'audioUrl': audioUrl,
      'userId': username,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await _sendPrayerNotification(
      title: 'New Prayer',
      body: title,
      userId: username,
    );
    // 4. Return prayer object
    return Prayer(
      id: docRef.id,
      title: title,
      audioUrl: audioUrl,
      userId: username,
      createdAt: now,
      expiresAt: expiresAt,
      subscribers: [],
    );
  }

  // Get all active prayers
  Stream<List<Prayer>> getActivePrayersForUser(String userName) {
    final now = DateTime.now();

    return _firestore
        .collection('prayers')
        .where('userId', isEqualTo: userName)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Prayer.fromDocument(doc)).toList();
        });
  }

  // Get user's own prayers
  Stream<List<Prayer>> getUserPrayers() {
    return _firestore
        .collection('prayers')
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Prayer.fromDocument(doc)).toList();
        });
  }

  // Delete an prayer
  Future<void> deletePrayer(String prayerId) async {
    try {
      final doc = await _firestore.collection('prayers').doc(prayerId).get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final audioUrl = data['audioUrl'] as String?; // Make nullable

      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          final storageRef = _storage.refFromURL(audioUrl);
          await storageRef.delete();
        } catch (e) {
          print('Error deleting audio file: $e');
        }
      }

      await _firestore.collection('prayers').doc(prayerId).delete();
    } catch (e) {
      print('Error deleting prayer: $e');
      rethrow;
    }
  }

  Future<void> updatePrayerAudio({
    required String prayerId,
    required File newAudioFile,
  }) async {
    // 1. Get the existing prayer document
    final docSnapshot =
        await _firestore.collection('prayers').doc(prayerId).get();

    if (!docSnapshot.exists) {
      throw Exception('Prayer not found');
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final oldAudioUrl = data['audioUrl'] as String?;

    // 2. Upload the new audio file to storage
    final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref().child('prayers/$fileName');
    final uploadTask = storageRef.putFile(newAudioFile);
    final snapshot = await uploadTask;
    final newAudioUrl = await snapshot.ref.getDownloadURL();

    // 3. Update the prayer document with the new audio URL
    await _firestore.collection('prayers').doc(prayerId).update({
      'audioUrl': newAudioUrl,
    });
    await _sendPrayerNotification(
      title: 'Prayer Updated',
      body: 'Audio content has been updated',
      prayerId: prayerId,
    );
    // 4. Delete the old audio file from storage if it exists
    if (oldAudioUrl != null) {
      try {
        final oldStorageRef = _storage.refFromURL(oldAudioUrl);
        await oldStorageRef.delete();
      } catch (e) {
        print('Error deleting old audio file: $e');
      }
    }

    print('Audio file updated successfully for prayer: $prayerId');
  }

  Future<void> deletePrayerAudio(String prayerId) async {
    // Get the prayer document
    final docSnapshot =
        await _firestore.collection('prayers').doc(prayerId).get();

    if (!docSnapshot.exists) {
      throw Exception('Prayer not found');
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final audioUrl = data['audioUrl'] as String;

    // Delete the audio file from storage
    try {
      final storageRef = _storage.refFromURL(audioUrl);
      await storageRef.delete();

      // Update the prayer document to remove the audioUrl
      await _firestore.collection('prayers').doc(prayerId).update({
        'audioUrl': FieldValue.delete(),
      });

      print('Audio file deleted successfully for prayer: $prayerId');
    } catch (e) {
      print('Error deleting audio file: $e');
      throw Exception('Failed to delete audio file: $e');
    }
  }

  Future<void> updatePrayerTitle(String prayerId, String newTitle) async {
    await _firestore.collection('prayers').doc(prayerId).update({
      'title': newTitle,
    });

    final prayerDoc =
        await _firestore.collection('prayers').doc(prayerId).get();

    if (prayerDoc.exists) {
      final prayerData = prayerDoc.data() as Map<String, dynamic>;
      final List<dynamic> subscribers = prayerData['subscribers'] ?? [];

      // Now subscribers are usernames
      for (String username in subscribers) {
        await _sendPrayerNotification(
          title: 'Prayer Updated',
          body: 'An prayer you follow has been updated. New title: $newTitle',
          userId: username,
          prayerId: prayerId,
        );
      }
    }
  }

  Future<String> getCurrentUsername() async {
    final userId = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('Users').doc(userId).get();
    return userDoc['username'] as String;
  }

  // Set up a background task to clean expired prayers
  // You might want to use Firebase Cloud Functions for this instead
  void setupExpirationTask() {
    // This is a simple implementation. In a production app, you would use
    // Cloud Functions or another server-side solution
    _firestore
        .collection('prayers')
        .where('expiresAt', isLessThan: Timestamp.fromDate(DateTime.now()))
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            final prayer = Prayer.fromDocument(doc);
            deletePrayer(prayer.id);
          }
        });
  }

  Future<void> _sendPrayerNotification({
    required String title,
    required String body,
    String? userId,
    String? prayerId,
  }) async {
    try {
      const String serverKey =
          'AAAAfwomSfk:APA91bH_4SJXRUglhcM0t3Y102vwQlwyGLgBQlHuTP6IbsQwfVjVxdKeA8VrEK2WlNyW0EqS-TR-HZo0YBHUPRG-Yvxc8cVx_vhDx_vPDiG2juWSwKh_4236I76Jp_OeRPpsn7imlxLX';

      final tokens = await _getUserFCMTokens(
        userId: userId,
        prayerId: prayerId,
      );

      if (tokens.isEmpty) {
        debugPrint('No valid FCM tokens found for notification');
        return;
      }

      final userMobileNumbers = await _getUserMobileNumbers(
        userId: userId,
        prayerId: prayerId,
      );

      // Create a list of futures for all notification sends
      final notificationFutures = <Future>[];

      for (int i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        String? mobileNumber =
            i < userMobileNumbers.length ? userMobileNumbers[i] : null;

        // Validate token format before sending
        if (!_isValidFcmToken(token)) {
          debugPrint('Invalid FCM token: $token');
          continue;
        }
        final String serverKey = await getAccessToken();

        final future = http
            .post(
              Uri.parse(
                "https://fcm.googleapis.com/v1/projects/moral-9f5c7/messages:send",
              ),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $serverKey',
              },
              body: jsonEncode(<String, dynamic>{
                "message": {
                  "token": token,
                  'notification': <String, dynamic>{
                    'body': body,
                    'title': title,
                    'sound': 'default',
                  },
                  'priority': 'high',
                  'data': <String, dynamic>{
                    'type': 'prayer',
                    'prayerId': prayerId ?? '',
                    'mobileNumber': mobileNumber ?? '',
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  // 'to': token,
                },
              }),
            )
            .then((response) {
              if (response.statusCode != 200) {
                debugPrint(
                  'Failed to send message to $token: ${response.statusCode} - ${response.body}',
                );

                // If unauthorized (401), the server key might be invalid
                if (response.statusCode == 401) {
                  throw Exception('Invalid FCM server key');
                }

                // If not found (404), the token might be invalid
                if (response.statusCode == 404) {
                  _handleInvalidToken(token, userId);
                }
              } else {
                debugPrint('Successfully sent notification to $token');
              }
            })
            .catchError((e) {
              debugPrint('Error sending notification to $token: $e');
            });

        notificationFutures.add(future);

        // Also create local notification if mobile number exists
        if (mobileNumber != null && mobileNumber.isNotEmpty) {
          notificationFutures.add(
            NotificationHelper.showPrayerNotification(
              title: title,
              body: body,
              prayerId: prayerId ?? '',
              userMobileNumber: mobileNumber,
            ).catchError((e) {
              debugPrint('Error showing local notification: $e');
            }),
          );
        }
      }

      // Wait for all notifications to complete
      await Future.wait(notificationFutures);
    } catch (e) {
      debugPrint('Error in _sendPrayerNotification: $e');
    }
  }

  bool _isValidFcmToken(String token) {
    return token.isNotEmpty && token.length > 10 && token.contains(':');
  }

  Future<void> _handleInvalidToken(String invalidToken, String? userId) async {
    try {
      if (userId == null) return;

      // Find and remove the invalid token from Firestore
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('username', isEqualTo: userId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final tokens = List<String>.from(doc['fcmTokens'] ?? []);

        if (tokens.contains(invalidToken)) {
          await doc.reference.update({
            'fcmTokens': FieldValue.arrayRemove([invalidToken]),
          });
          debugPrint('Removed invalid FCM token for user $userId');
        }
      }
    } catch (e) {
      debugPrint('Error handling invalid token: $e');
    }
  }

  Future<List<String>> _getUserMobileNumbers({
    String? userId,
    String? prayerId,
  }) async {
    List<String> mobileNumbers = [];

    if (userId != null) {
      // Fetch a single user by ID

      final doc =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('username', isEqualTo: userId)
              .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        final number = data['mobileNumber'];
        if (number != null && number is String) {
          mobileNumbers.add(number);
        }
      } else {
        print('No user found with userId: $userId');
      }
    } else if (prayerId != null) {
      // Fetch users related to a specific prayer
      final prayerDoc =
          await FirebaseFirestore.instance
              .collection('prayers')
              .doc(prayerId)
              .get();

      if (prayerDoc.exists) {
        final data = prayerDoc.data();
        final List<dynamic>? relatedUserIds = data?['targetUserIds'];

        if (relatedUserIds != null) {
          for (final uid in relatedUserIds) {
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(uid)
                    .get();

            if (userDoc.exists) {
              final userData = userDoc.data();
              final number = userData?['mobileNumber'];
              if (number != null && number is String) {
                mobileNumbers.add(number);
              }
            }
          }
        }
      } else {
        print('No prayer found with ID: $prayerId');
      }
    }

    return mobileNumbers;
  }

  // Get FCM tokens for users who should be notified
  Future<List<String>> _getUserFCMTokens({
    String? userId,
    String? prayerId,
  }) async {
    try {
      if (userId != null) {
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('Users')
                .where('username', isEqualTo: userId)
                .limit(1)
                .get();

        if (querySnapshot.docs.isEmpty) {
          debugPrint('No user found with username: $userId');
          return [];
        }

        final userData = querySnapshot.docs.first.data();
        final tokens = _extractTokensFromUserData(userData);

        // Add validation for FCM token format
        return tokens
            .where(
              (token) =>
                  token.isNotEmpty &&
                  token.length > 10 && // Basic validation
                  token.contains(':'), // FCM tokens typically contain colons
            )
            .toList();
      }

      if (prayerId != null) {
        return await _getTokensForPrayerSubscribers(prayerId);
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching FCM tokens: $e');
      return [];
    }
  }

  List<String> _extractTokensFromUserData(Map<String, dynamic> userData) {
    try {
      final tokens = userData['fcmTokens'];

      // Handle various possible cases
      if (tokens == null) return [];
      if (tokens is List) {
        return tokens.whereType<String>().where((t) => t.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error extracting tokens: $e');
      return [];
    }
  }

  /// Gets tokens for all subscribers of an prayer
  Future<List<String>> _getTokensForPrayerSubscribers(String prayerId) async {
    try {
      final prayerDoc =
          await FirebaseFirestore.instance
              .collection('prayers')
              .doc(prayerId)
              .get();

      if (!prayerDoc.exists) {
        debugPrint('Prayer not found: $prayerId');
        return [];
      }

      final subscribers = List<String>.from(
        prayerDoc.data()?['subscribers'] ?? [],
      );

      if (subscribers.isEmpty) return [];

      // Get all users who are subscribers
      final usersQuery =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('username', whereIn: subscribers)
              .get();

      return usersQuery.docs
          .expand((doc) => _extractTokensFromUserData(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting prayer subscribers tokens: $e');
      return [];
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
