import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fourmoral/constants/strings.dart';
import 'package:fourmoral/firebase_options.dart';
import 'package:fourmoral/screens/logInScreen/log_in_screen.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';
import 'package:fourmoral/screens/notificationScreen/notification_helper.dart';
import 'package:fourmoral/screens/product/recent_category_service.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/services/announcement_service.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:fourmoral/widgets/upload_bar.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'screens/infoGatheringScreen/info_gathering_screen.dart';
import 'services/scroll_behaviour.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Global instances
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationHelper.initialize();
  if (message.notification != null) {
    NotificationHelper.showNotification(
      title: message.notification?.title ?? 'New notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }
}

class AppInitializer {
  static Future<void> initialize() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    await _initializeFirebase();
    await _initializeAppCheck();
    await _initializeStorage();
    await _initializePreferences();
    await _initializeControllers();
    await _initializePermissions();
    await _initializeNotificationServices();
    await _initializeUserState();
    await _startScheduledTasks();
  }

  static Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialized successfully");
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
      rethrow;
    }
  }

  static Future<void> _initializeAppCheck() async {
    try {
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.appAttest,
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }
    } catch (e) {
      debugPrint("App Check initialization failed: $e");
    }
  }

  static Future<void> _initializeStorage() async {
    try {
      await GetStorage.init();
      debugPrint("GetStorage initialized successfully");
    } catch (e) {
      debugPrint("GetStorage initialization failed: $e");
    }
  }

  static Future<void> _initializePreferences() async {
    try {
      await AppPreference().initialAppPreference();
      debugPrint("Preferences initialized successfully");
    } catch (e) {
      debugPrint("Preferences initialization failed: $e");
    }
  }

  static Future<void> _initializeControllers() async {
    try {
      Get.put(RecentCategoryService());
      Get.put(Story2Controller());
      debugPrint("Controllers initialized successfully");
    } catch (e) {
      debugPrint("Controllers initialization failed: $e");
    }
  }

  static Future<void> _initializePermissions() async {
    try {
      final permissions = [
        Permission.camera,
        Permission.storage,
        Permission.contacts,
        Permission.notification,
        if (Platform.isAndroid) Permission.systemAlertWindow,
      ];

      for (final permission in permissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          await permission.request();
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint("Permissions initialized successfully");
    } catch (e) {
      debugPrint("Permissions initialization failed: $e");
    }
  }

  static Future<void> _initializeNotificationServices() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await NotificationHelper.initialize();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await flutterLocalNotificationsPlugin.initialize(
        InitializationSettings(android: initializationSettingsAndroid),
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (Platform.isIOS) {
        try {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            FirebaseMessaging.instance.onTokenRefresh.listen(_storeFCMToken);
          } else {
            final initialToken = await FirebaseMessaging.instance.getToken();
            await _storeFCMToken(initialToken);
          }
        } catch (e) {
          debugPrint('Error getting APNs token: $e');
        }
      } else {
        final initialToken = await FirebaseMessaging.instance.getToken();
        await _storeFCMToken(initialToken);
        FirebaseMessaging.instance.onTokenRefresh.listen(_storeFCMToken);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          NotificationHelper.showNotification(
            title: message.notification?.title ?? 'New notification',
            body: message.notification?.body ?? '',
            payload: message.data.toString(),
          );
        }
      });

      debugPrint("Notification services initialized successfully");
    } catch (e) {
      debugPrint("Notification services initialization failed: $e");
    }
  }

  static Future<void> _initializeUserState() async {
    try {
      final String userPhoneNumber =
          AppPreference().getString(PreferencesKey.userPhoneNumber).toString();
      if (userPhoneNumber.isNotEmpty) {
        await _loadUserProfile(userPhoneNumber);
      }
      debugPrint("User state initialized successfully");
    } catch (e) {
      debugPrint("User state initialization failed: $e");
    }
  }

  static Future<void> _startScheduledTasks() async {
    try {
      final announcementService = AnnouncementService();
      Timer.periodic(const Duration(hours: 1), (_) async {
        try {
          await announcementService.checkScheduledAnnouncements();
        } catch (e) {
          debugPrint("Error checking announcements: $e");
        }
      });
      debugPrint("Scheduled tasks started successfully");
    } catch (e) {
      debugPrint("Scheduled tasks initialization failed: $e");
    }
  }

  static Future<void> _loadUserProfile(String phoneNumber) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('mobileNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        await _ensureFCMTokensInitialized(snapshot.docs.first.reference);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  static Future<void> _ensureFCMTokensInitialized(
    DocumentReference userRef,
  ) async {
    try {
      final doc = await userRef.get();
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null || !data.containsKey('fcmTokens')) {
        final token = await FirebaseMessaging.instance.getToken();
        await userRef.set({
          'fcmTokens': token != null ? [token] : [],
          'notificationEnabled': true,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error ensuring FCM tokens: $e');
    }
  }

  static Future<void> _storeFCMToken(String? token) async {
    if (token == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('Users')
            .where(
              'mobileNumber',
              isEqualTo:
                  AppPreference()
                      .getString(PreferencesKey.userPhoneNumber)
                      .toString(),
            )
            .limit(1);

        final snapshot = await userDoc.get();
        if (snapshot.docs.isNotEmpty) {
          final docRef = snapshot.docs.first.reference;
          final docData = snapshot.docs.first.data();

          final List<String> currentTokens =
              (docData['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];

          if (!currentTokens.contains(token)) {
            await docRef.update({
              'fcmTokens': FieldValue.arrayUnion([token]),
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error storing FCM token: $e');
    }
  }
}

Future<void> main() async {
  try {
    await AppInitializer.initialize();

    final navigatorKey = GlobalKey<NavigatorState>();
    final loggedIn = AppPreference().getBool(PreferencesKey.loggedIn);
    final infoGathered = AppPreference().getBool(PreferencesKey.infoGathered);
    final userPhoneNumber =
        AppPreference().getString(PreferencesKey.userPhoneNumber).toString();

    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => UploadManager())],
        child: MyApp(
          navigatorKey: navigatorKey,
          loggedIn: loggedIn,
          infoGathered: infoGathered,
          userPhoneNumber: userPhoneNumber,
        ),
      ),
    );
    FlutterNativeSplash.remove();
  } catch (e, stackTrace) {
    debugPrint("Critical error during app initialization: $e");
    debugPrint("Stack trace: $stackTrace");

    runApp(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              "There was an error initializing the app. Please restart.",
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  final bool infoGathered;
  final String userPhoneNumber;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({
    super.key,
    required this.loggedIn,
    required this.infoGathered,
    required this.userPhoneNumber,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return GetMaterialApp(
      navigatorKey: navigatorKey,
      builder: (BuildContext context, Widget? child) {
        return SafeArea(
          bottom: true,
          top: false,
          left: false,
          right: false,
          child: ScrollConfiguration(
            behavior: MyBehavior(),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: PositionedUploadBar(),
                ),
              ],
            ),
          ),
        );
      },
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData(
        fontFamily: 'Poppins',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _getHomeScreen(),
    );
  }

  Widget _getHomeScreen() {
    if (!loggedIn) {
      return const LoginScreen();
    }

    if (infoGathered) {
      return NavigationBarCustom(userPhoneNumber: userPhoneNumber);
    }

    return InfoGatheringScreen(userPhoneNumber: userPhoneNumber);
  }
}
