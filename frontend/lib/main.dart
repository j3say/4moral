import 'package:flutter/material.dart';
import 'package:frontend/screens/onboarding/community_guidelines_screen.dart';
import 'package:frontend/screens/onboarding/preferences_screen.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/terms_conditions_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'models/user_model.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/profile/profile_page.dart';

// Global instance for identity hydration
UserModel? currentUser;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Local Storage
  await GetStorage.init(); 
  
  // 2. Hydrate session if token exists
  await hydrateUserSession();
  
  runApp(const FourMoralApp());
}

/// Fetches user identity from MongoDB before app launch
Future<void> hydrateUserSession() async {
  final storage = GetStorage();
  final api = ApiService();
  String? token = storage.read('jwt_token');

  if (token != null) {
    try {
      final userData = await api.getMe();
      currentUser = UserModel.fromMap(userData);
      debugPrint("Session Hydrated: ${currentUser?.mobileNumber}");
    } catch (e) {
      debugPrint("Hydration Failed: $e");
      storage.remove('jwt_token'); // Clear invalid session
    }
  }
}

class FourMoralApp extends StatelessWidget {
  const FourMoralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: '4Moral',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LoginScreen()),
        GetPage(name: '/TermsConditionsScreen', page: () => const TermsConditionsScreen()),
        GetPage(name: '/CommunityGuidelinesScreen', page: () => const CommunityGuidelinesScreen()),
        GetPage(name: '/PreferencesScreen', page: () => const PreferencesScreen()),
        GetPage(name: '/ProfileSetupScreen', page: () => const ProfileSetupScreen(selectedCommunities: [])),
      ],
      theme: ThemeData(
        // Using Google Fonts Poppins for the modern look
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Logic-based initial route
      home: _getInitialScreen(),
    );
  }

  /// Determines the entry point based on Auth and Profile status
  Widget _getInitialScreen() {
    if (currentUser == null) {
      return const LoginScreen(); // Flow Start: Auth
    }
    
    // If logged in but profile is incomplete, send back to onboarding
    if (currentUser!.profileCompleted == false) {
      return const TermsConditionsScreen(); 
    }
    
    return const HomeScreen(); // Final Destination
  }
}