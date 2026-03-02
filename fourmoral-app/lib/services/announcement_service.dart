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

import '../models/announcement.dart';

class AnnouncementService {
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

  Future<void> checkScheduledAnnouncements() async {
    await processScheduledAnnouncements(); // Calls the extension method
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

  Future<void> toggleAnnouncementNotification(
    String announcementId,
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

    await _firestore.collection('announcements').doc(announcementId).update({
      'subscribers':
          enable
              ? FieldValue.arrayUnion([fetchedUsername])
              : FieldValue.arrayRemove([fetchedUsername]),
    });

    if (enable) {
      print('enable 111');
      try {
        final announcementDoc =
            await _firestore
                .collection('announcements')
                .doc(announcementId)
                .get();

        if (announcementDoc.exists) {
          final announcement = Announcement.fromDocument(announcementDoc);

          // Send notification only to the subscribing user
          await _sendAnnouncementNotification(
            title: 'Subscription Confirmed',
            body: 'You will receive updates for: ${announcement.title}',
            userId: username, // Send only to this user
            announcementId: announcementId,
          );
        }
      } catch (e) {
        print('Error sending subscription notification: $e');
      }
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // Create a new announcement
  Future<Announcement> createAnnouncement({
    required String title,
    required String username,
    required File audioFile,
    Map<String, dynamic>? schedule, // Add optional schedule parameter
  }) async {
    // 1. Upload audio file to storage
    final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref().child('announcements/$fileName');
    final uploadTask = storageRef.putFile(audioFile);
    final snapshot = await uploadTask;
    final audioUrl = await snapshot.ref.getDownloadURL();

    // 2. Calculate expiration time (24 hours from now if not scheduled)
    final now = DateTime.now();
    final expiresAt =
        schedule != null
            ? now.add(const Duration(days: 365)) // Longer expiry for scheduled
            : now.add(const Duration(hours: 24));

    // 3. Create announcement document with optional schedule
    final announcementData = {
      'title': title,
      'audioUrl': audioUrl,
      'userId': username,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'schedule':
          schedule ??
          {
            "type": "dates",
            "dates": [Timestamp.fromDate(now)],
            "time": _formatTime(now),
          }, // Only add if exists
    };

    final docRef = await _firestore
        .collection('announcements')
        .add(announcementData);

    // 4. Send notification (only if immediate announcement)
    if (schedule == null) {
      await _sendAnnouncementNotification(
        title: 'New Announcement',
        body: title,
        userId: username,
      );
    }

    // 5. Return announcement object
    return Announcement(
      id: docRef.id,
      title: title,
      audioUrl: audioUrl,
      userId: username,
      createdAt: now,
      expiresAt: expiresAt,
      subscribers: [],
      schedule: schedule, // Include in returned object
    );
  }

  // Get all active announcements
  Stream<List<Announcement>> getActiveAnnouncementsForUser(String userName) {
    final now = DateTime.now();

    return _firestore
        .collection('announcements')
        .where('userId', isEqualTo: userName)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromDocument(doc))
              .where(
                (announcement) => _shouldShowAnnouncement(announcement, now),
              )
              .toList();
        });
  }

  bool _shouldShowAnnouncement(Announcement announcement, DateTime now) {
    // If no schedule, show immediately
    if (announcement.schedule == null) return true;

    final schedule = announcement.schedule!;

    if (schedule['type'] == 'dates') {
      final dates = (schedule['dates'] as List).map(
        (t) => (t as Timestamp).toDate(),
      );
      return dates.any((date) => _isSameDay(date, now));
    } else {
      final days = schedule['days'] as List<dynamic>;
      return days.contains(now.weekday);
    }
  }

  // Get user's own announcements
  Stream<List<Announcement>> getUserAnnouncements(String username) {
    return _firestore
        .collection('announcements')
        .where('userId', isEqualTo: username)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromDocument(doc))
              .toList();
        });
  }

  // Delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final doc =
          await _firestore
              .collection('announcements')
              .doc(announcementId)
              .get();

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

      await _firestore.collection('announcements').doc(announcementId).delete();
    } catch (e) {
      print('Error deleting announcement: $e');
      rethrow;
    }
  }

  Future<void> updateAnnouncementAudio({
    required String announcementId,
    required File newAudioFile,
  }) async {
    // 1. Get the existing announcement document
    final docSnapshot =
        await _firestore.collection('announcements').doc(announcementId).get();

    if (!docSnapshot.exists) {
      throw Exception('Announcement not found');
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final oldAudioUrl = data['audioUrl'] as String?;

    // 2. Upload the new audio file to storage
    final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref().child('announcements/$fileName');
    final uploadTask = storageRef.putFile(newAudioFile);
    final snapshot = await uploadTask;
    final newAudioUrl = await snapshot.ref.getDownloadURL();

    // 3. Update the announcement document with the new audio URL
    await _firestore.collection('announcements').doc(announcementId).update({
      'audioUrl': newAudioUrl,
    });
    await _sendAnnouncementNotification(
      title: 'Announcement Updated',
      body: 'Audio content has been updated',
      announcementId: announcementId,
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

    print('Audio file updated successfully for announcement: $announcementId');
  }

  Future<void> deleteAnnouncementAudio(String announcementId) async {
    // Get the announcement document
    final docSnapshot =
        await _firestore.collection('announcements').doc(announcementId).get();

    if (!docSnapshot.exists) {
      throw Exception('Announcement not found');
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final audioUrl = data['audioUrl'] as String;

    // Delete the audio file from storage
    try {
      final storageRef = _storage.refFromURL(audioUrl);
      await storageRef.delete();

      // Update the announcement document to remove the audioUrl
      await _firestore.collection('announcements').doc(announcementId).update({
        'audioUrl': FieldValue.delete(),
      });

      print(
        'Audio file deleted successfully for announcement: $announcementId',
      );
    } catch (e) {
      print('Error deleting audio file: $e');
      throw Exception('Failed to delete audio file: $e');
    }
  }

  Future<void> updateAnnouncementTitle(
    String announcementId,
    String newTitle,
  ) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'title': newTitle,
    });

    final announcementDoc =
        await _firestore.collection('announcements').doc(announcementId).get();

    if (announcementDoc.exists) {
      final announcementData = announcementDoc.data() as Map<String, dynamic>;
      final List<dynamic> subscribers = announcementData['subscribers'] ?? [];

      // Now subscribers are usernames
      for (String username in subscribers) {
        await _sendAnnouncementNotification(
          title: 'Announcement Updated',
          body:
              'An announcement you follow has been updated. New title: $newTitle',
          userId: username,
          announcementId: announcementId,
        );
      }
    }
  }

  Future<String> getCurrentUsername() async {
    final userId = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('Users').doc(userId).get();
    return userDoc['username'] as String;
  }

  // Set up a background task to clean expired announcements
  // You might want to use Firebase Cloud Functions for this instead
  void setupExpirationTask() {
    // This is a simple implementation. In a production app, you would use
    // Cloud Functions or another server-side solution
    _firestore
        .collection('announcements')
        .where('expiresAt', isLessThan: Timestamp.fromDate(DateTime.now()))
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            final announcement = Announcement.fromDocument(doc);
            deleteAnnouncement(announcement.id);
          }
        });
  }

  Future<void> _sendAnnouncementNotification({
    required String title,
    required String body,
    String? userId,
    String? announcementId,
  }) async {
    try {
      // const String serverKey =
      //     'AAAAfwomSfk:APA91bH_4SJXRUglhcM0t3Y102vwQlwyGLgBQlHuTP6IbsQwfVjVxdKeA8VrEK2WlNyW0EqS-TR-HZo0YBHUPRG-Yvxc8cVx_vhDx_vPDiG2juWSwKh_4236I76Jp_OeRPpsn7imlxLX';

      final tokens = await _getUserFCMTokens(
        userId: userId,
        announcementId: announcementId,
      );

      if (tokens.isEmpty) {
        debugPrint('No valid FCM tokens found for notification');
        return;
      }

      final userMobileNumbers = await _getUserMobileNumbers(
        userId: userId,
        announcementId: announcementId,
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
                  "notification": {'body': body, 'title': title},

                  // 'notification': <String, dynamic>{
                  //   'body': body,
                  //   'title': title,
                  //   'sound': 'default',
                  // },
                  'data': <String, dynamic>{
                    'type': 'announcement',
                    'announcementId': announcementId ?? '',
                    'mobileNumber': mobileNumber ?? '',
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  },
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
            NotificationHelper.showAnnouncementNotification(
              title: title,
              body: body,
              announcementId: announcementId ?? '',
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
      debugPrint('Error in _sendAnnouncementNotification: $e');
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
    String? announcementId,
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
    } else if (announcementId != null) {
      // Fetch users related to a specific announcement
      final announcementDoc =
          await FirebaseFirestore.instance
              .collection('announcements')
              .doc(announcementId)
              .get();

      if (announcementDoc.exists) {
        final data = announcementDoc.data();
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
        print('No announcement found with ID: $announcementId');
      }
    }

    return mobileNumbers;
  }

  // Get FCM tokens for users who should be notified
  Future<List<String>> _getUserFCMTokens({
    String? userId,
    String? announcementId,
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

      if (announcementId != null) {
        return await _getTokensForAnnouncementSubscribers(announcementId);
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

  /// Gets tokens for all subscribers of an announcement
  Future<List<String>> _getTokensForAnnouncementSubscribers(
    String announcementId,
  ) async {
    try {
      final announcementDoc =
          await FirebaseFirestore.instance
              .collection('announcements')
              .doc(announcementId)
              .get();

      if (!announcementDoc.exists) {
        debugPrint('Announcement not found: $announcementId');
        return [];
      }

      final subscribers = List<String>.from(
        announcementDoc.data()?['subscribers'] ?? [],
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
      debugPrint('Error getting announcement subscribers tokens: $e');
      return [];
    }
  }
}

extension AnnouncementExtensions on AnnouncementService {
  Future<void> processScheduledAnnouncements() async {
    final now = DateTime.now();
    final scheduled =
        await _firestore
            .collection('announcements')
            .where('schedule', isNotEqualTo: null)
            .get();

    for (final doc in scheduled.docs) {
      final data = doc.data();
      final schedule = data['schedule'] as Map<String, dynamic>;

      if (_shouldSendNow(schedule, now)) {
        await _sendScheduledAnnouncement(doc.id, data);
      }
    }
  }

  bool _shouldSendNow(Map<String, dynamic> schedule, DateTime now) {
    if (schedule['type'] == 'dates') {
      final dates = (schedule['dates'] as List).map(
        (t) => (t as Timestamp).toDate(),
      );
      return dates.any((date) => _isSameDay(date, now));
    } else {
      final days = schedule['days'] as List<int>;
      return days.contains(now.weekday);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _sendScheduledAnnouncement(
    String id,
    Map<String, dynamic> data,
  ) async {
    // Check if already sent today
    final lastSent = data['lastSent'] as Timestamp?;
    if (lastSent != null && _isSameDay(lastSent.toDate(), DateTime.now())) {
      return;
    }

    // Send notification
    await _sendAnnouncementNotification(
      title: 'Scheduled Announcement',
      body: data['title'],
      userId: data['userId'],
    );

    // Update last sent time
    await _firestore.collection('announcements').doc(id).update({
      'lastSent': Timestamp.now(),
    });
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
