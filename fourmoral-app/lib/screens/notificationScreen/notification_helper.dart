import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static final DatabaseReference _notificationsRef = FirebaseDatabase.instance
      .ref()
      .child('Users');

  // Initialize notifications
  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // InitializationSettings for initializing both platforms
    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
          NotificationResponse notificationResponse,
          ) async {
        // Handle notification tap
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          // Navigate to specific screen based on payload
          // This would need to be handled in your app's navigation
          print('Notification tapped with payload: $payload');
        }
      },
    );

    // Set up Firebase Messaging for receiving FCM notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Handle foreground FCM messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      await showNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data['announcementId'] ?? '',
      );

      // Also store in Firebase database for in-app notification
      await _storeNotificationInDatabase(message);
    }
  }

  // Store notification in Firebase for in-app display
  static Future<void> _storeNotificationInDatabase(
      RemoteMessage message,
      ) async {
    try {
      final userMobileNumber = message.data['mobileNumber'] ?? '';
      if (userMobileNumber.isEmpty) return;

      final notificationsRef = _notificationsRef
          .child(userMobileNumber)
          .child('Notifications');

      final newNotificationKey = notificationsRef.push().key;

      if (newNotificationKey == null) return;

      await notificationsRef.child(newNotificationKey).set({
        'type': 'announcement',
        'title': message.notification?.title ?? 'New Announcement',
        'message': message.notification?.body ?? '',
        'time': DateTime.now().toIso8601String(),
        'mobileNumber': userMobileNumber,
        'announcementId': message.data['announcementId'] ?? '',
        'profilePicture': message.data['profilePicture'] ?? '',
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message,
      ) async {
    // This will be called when the app receives a notification while in the background
    print('Handling a background message: ${message.messageId}');

    // Store the notification in the database for when the app opens
    await _storeNotificationInDatabase(message);
  }

  // Show a local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'announcements_channel', // channel id
      'Announcements', // channel name
      channelDescription: 'Channel for announcement notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      0, // notification id
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Method to display a notification immediately (can be called from anywhere in your app)
  static Future<void> showAnnouncementNotification({
    required String title,
    required String body,
    required String announcementId,
    required String userMobileNumber,
  }) async {
    // Show system notification
    await showNotification(title: title, body: body, payload: announcementId);

    // Also store in Firebase for in-app notification
    try {
      final notificationsRef = _notificationsRef
          .child(userMobileNumber)
          .child('Notifications');

      final newNotificationKey = notificationsRef.push().key;

      if (newNotificationKey == null) return;

      await notificationsRef.child(newNotificationKey).set({
        'type': 'announcement',
        'title': title,
        'message': body,
        'time': DateTime.now().toIso8601String(),
        'mobileNumber': userMobileNumber,
        'announcementId': announcementId,
        'profilePicture': '', // You may want to add a default announcement icon
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  static Future<void> showPrayerNotification({
    required String title,
    required String body,
    required String prayerId,
    required String userMobileNumber,
  }) async {
    // Show system notification
    await showNotification(title: title, body: body, payload: prayerId);

    // Also store in Firebase for in-app notification
    try {
      final notificationsRef = _notificationsRef
          .child(userMobileNumber)
          .child('Notifications');

      final newNotificationKey = notificationsRef.push().key;

      if (newNotificationKey == null) return;

      await notificationsRef.child(newNotificationKey).set({
        'type': 'prayer',
        'title': title,
        'message': body,
        'time': DateTime.now().toIso8601String(),
        'mobileNumber': userMobileNumber,
        'prayerId': prayerId,
        'profilePicture': '', // You may want to add a default prayer icon
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }
}
