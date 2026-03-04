import 'dart:convert';
import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/infoGatheringScreen/info_gathering_screen.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';
import 'package:fourmoral/services/api_service.dart'; // Import your ApiService
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController(); // Added Password Controller

  RxString phoneNumber = ''.obs;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isRegistering = false; // Toggle between Login and Register
  bool _obscurePassword = true;

  // Handles both Login and Register based on _isRegistering state
  Future<void> _handleAuth() async {
    final phone = phoneNumber.value.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter mobile number and password"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final endpoint =
          _isRegistering ? '/api/auth/register' : '/api/auth/login';
      final url = Uri.parse('${ApiService.baseUrl}$endpoint');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobileNumber': phone,
          'password': password,
          // 'fcmToken': ... // Add FCM token here if needed later
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final String token = data['token'];
        final Map<String, dynamic> user =
            data['data'] != null ? data['data']['user'] : data['user'];
        final bool profileCompleted = user['profileCompleted'] ?? false;

        // Save Preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'token',
          token,
        ); // IMPORTANT: Save token for API calls
        await AppPreference().setBool(PreferencesKey.loggedIn, true);
        await AppPreference().setString(PreferencesKey.userPhoneNumber, phone);
        await AppPreference().setBool(
          PreferencesKey.infoGathered,
          profileCompleted,
        );

        // Navigate based on profile status
        Get.off(
          () =>
              profileCompleted
                  ? NavigationBarCustom(userPhoneNumber: phone)
                  : InfoGatheringScreen(userPhoneNumber: phone),
        );
      } else {
        // API Error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Authentication failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DoubleBackToCloseApp(
        snackBar: const SnackBar(content: Text('Double Press to Exit')),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                child: Image.asset('assets/main_top.png', width: 120),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Image.asset('assets/main_bottom.png', width: 120),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              "WELCOME TO MORAL 1",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 30),
                            SvgPicture.asset("assets/chat.svg", height: 200),
                            const SizedBox(height: 30),

                            // --- Mobile Field ---
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Enter your mobile number",
                                style: TextStyle(
                                  color: black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            IntlPhoneField(
                              cursorColor: Colors.deepPurple,
                              dropdownIconPosition: IconPosition.trailing,
                              flagsButtonPadding: const EdgeInsets.only(
                                left: 12,
                              ),
                              dropdownIcon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              controller: _mobileNumberController,
                              decoration: InputDecoration(
                                hintText: "Phone Number",
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(
                                    color: Colors.blueGrey,
                                    width: 2.0,
                                  ),
                                ),
                              ),
                              initialCountryCode: 'IN',
                              onSaved: (phone) {
                                phoneNumber.value = phone?.completeNumber ?? "";
                              },
                              onChanged: (phone) {
                                phoneNumber.value = phone.completeNumber;
                              },
                            ),
                            const SizedBox(height: 20),

                            // --- Password Field ---
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Enter Password",
                                style: TextStyle(
                                  color: black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: "Password",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      ),
                                ),
                              ),
                              validator:
                                  (val) =>
                                      val != null && val.length < 6
                                          ? "Password must be 6+ chars"
                                          : null,
                            ),

                            const SizedBox(height: 30),

                            // --- Action Button ---
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _handleAuth();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFF6F35A5),
                                shape: const StadiumBorder(),
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              child:
                                  _isLoading
                                      ? const CupertinoActivityIndicator(
                                        color: Colors.white,
                                      )
                                      : Text(
                                        _isRegistering ? "REGISTER" : "LOGIN",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),

                            // --- Toggle Login/Register ---
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isRegistering
                                      ? "Already have an account? "
                                      : "Don't have an account? ",
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isRegistering = !_isRegistering;
                                    });
                                  },
                                  child: Text(
                                    _isRegistering ? "Login" : "Register",
                                    style: const TextStyle(
                                      color: Color(0xFF6F35A5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
