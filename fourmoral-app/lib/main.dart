import 'dart:async';
import 'dart:io';
// ❌ ALL FIREBASE IMPORTS REMOVED ❌

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fourmoral/constants/strings.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/logInScreen/log_in_screen.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';
import 'package:fourmoral/screens/notificationScreen/notification_helper.dart';
import 'package:fourmoral/screens/product/recent_category_service.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/services/announcement_service.dart';
import 'package:fourmoral/services/api_service.dart';
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
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Global instances
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
  
// Global instance for Profile Data
ProfileModel? globalProfile;

class AppInitializer {
  static Future<void> initialize() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // ❌ FIREBASE & APP CHECK INITIALIZATION COMPLETELY REMOVED ❌
    
    await _initializeStorage();
    await _initializePreferences();
    await _initializeControllers();
    await _initializePermissions();
    await _initializeNotificationServices(); // Now only local notifications
    // await _initializeUserState(); // GOD MODE INJECTED HERE
    await initUserSession();
    await _startScheduledTasks();
  }

  static Future<void> initUserSession() async {
    final storage = GetStorage();
    final apiService = ApiService();
    String? token = storage.read('jwt_token');

    if (token != null) {
      try {
        debugPrint("Identity Hydration: Fetching profile from MongoDB...");
        final userData = await apiService.getMe();
        
        // 2.2: Populate global profileDataModel
        // Assuming your model has a fromMap/fromJson factory
        globalProfile = ProfileModel.fromMap(userData); 
        
        debugPrint("Session Active: Role is ${globalProfile?.type}");
      } catch (e) {
        debugPrint("Hydration Failed: $e");
        storage.remove('jwt_token');
      }
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
      if (kIsWeb) {
        debugPrint("Web detected: Skipping mobile permission checks.");
        return;
      }

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
      // ❌ FCM (Firebase Cloud Messaging) Removed. Only Local Notifications remain.
      await NotificationHelper.initialize();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(android: initializationSettingsAndroid),
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );

      debugPrint("Local Notification services initialized successfully");
    } catch (e) {
      debugPrint("Notification services initialization failed: $e");
    }
  }

  static Future<void> _initializeUserState() async {
    try {
      // 🚀 THE GOD-MODE BYPASS 🚀
      // We are forcing the app to believe you are fully logged in so you bypass the broken login screens.
      AppPreference().setBool(PreferencesKey.loggedIn, true);
      AppPreference().setBool(PreferencesKey.infoGathered, true);
      AppPreference().setString(PreferencesKey.userPhoneNumber, "+919999999999");
      
      // Note: Yameesh needs to ensure the UI logic treating you as "HolyPlace" 
      // is hardcoded wherever the Profile Model is generated in the UI.

      debugPrint("GOD MODE: User state forced to Logged In");
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

  // ❌ _loadUserProfile (Firestore) Removed ❌
  // ❌ _ensureFCMTokensInitialized (Firestore) Removed ❌
  // ❌ _storeFCMToken (Firestore) Removed ❌
}

Future<void> main() async {
  try {
    await AppInitializer.initialize();
    final navigatorKey = GlobalKey<NavigatorState>();
    
    // Grabbing the God-Mode values we just set
    // final loggedIn = AppPreference().getBool(PreferencesKey.loggedIn);
    // final infoGathered = AppPreference().getBool(PreferencesKey.infoGathered);
    // final userPhoneNumber = AppPreference().getString(PreferencesKey.userPhoneNumber).toString();

    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => UploadManager())],
        child: MyApp(
          navigatorKey: navigatorKey
          // loggedIn: loggedIn,
          // infoGathered: infoGathered,
          // userPhoneNumber: userPhoneNumber,
        ),
      ),
    );
    FlutterNativeSplash.remove();
  } catch (e, stackTrace) {
    debugPrint("Critical error during app initialization: $e");
    debugPrint("Stack trace: $stackTrace");

    runApp(
      const GetMaterialApp(
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
  // final bool loggedIn;
  // final bool infoGathered;
  // final String userPhoneNumber;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({
    super.key,
    // required this.loggedIn,
    // required this.infoGathered,
    // required this.userPhoneNumber,
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
      initialRoute: "/", 
      getPages: [
        GetPage(name: "/", page: () => _getHomeScreen()),
        GetPage(name: "/login", page: () => const LoginScreen()),
      ],
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
    final storage = GetStorage();
    String? token = storage.read('jwt_token');
    if (token == null) return const LoginScreen();
    if (globalProfile != null) {
      return NavigationBarCustom(userPhoneNumber: globalProfile?.mobileNumber ?? "");
  }
    String savedPhone = storage.read('userPhoneNumber') ?? "";
    return InfoGatheringScreen(userPhoneNumber: savedPhone);
  }
}