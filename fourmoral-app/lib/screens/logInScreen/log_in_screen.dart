import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/infoGatheringScreen/info_gathering_screen.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';
import 'package:fourmoral/screens/videoAndVoiceCall/constants.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  RxString phoneNumber = ''.obs;
  final _formKeyMobileNumber = GlobalKey<FormState>();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  Future<void> _sendOtp() async {
    try {
      final phone = phoneNumber.value.trim();
      if (phone.isEmpty || !RegExp(r'^\+\d{10,15}$').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Enter a valid phone number (e.g., +919876543210)"),
          ),
        );
        return;
      }

      print("Sending OTP to: $phone");
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("Auto-verification completed: $credential");
          await _signInWithCredential(credential, phone);
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Verification failed: ${e.code}, ${e.message}");
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message ?? "OTP Failed")));
        },
        codeSent: (String verificationId, int? resendToken) {
          print("OTP sent, verificationId: $verificationId");
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("Auto-retrieval timeout: $verificationId");
          _verificationId = verificationId;
        },
      );
    } catch (e, stackTrace) {
      print("Error in _sendOtp: $e\n$stackTrace");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    }
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6 || _verificationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter valid 6-digit OTP")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential, phoneNumber.value.trim());
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OTP Verification Failed")));
    }
  }

  Future<void> _signInWithCredential(
    AuthCredential authCreds,
    String phone,
  ) async {
    try {
      print("Starting sign-in with credential: $authCreds");
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      print("APNs Token: $apnsToken");
      if (apnsToken == null) {
        print("Warning: APNs token is null, may cause issues on iOS");
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(authCreds);
      print("User signed in: ${userCredential.user?.uid}");
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      print("FCM Token: $fcmToken");

      final collection = FirebaseFirestore.instance.collection('Users');
      final query =
          await collection
              .where('mobileNumber', isEqualTo: phone)
              .limit(1)
              .get();
      if (query.docs.isEmpty) {
        print("New user, adding to Firestore");
        await collection.add({
          'mobileNumber': phone,
          'infoGathered': false,
          'notificationEnabled': true,
          'fcmTokens': fcmToken != null ? [fcmToken] : [],
          'createdAt': FieldValue.serverTimestamp(),
          'uid': userCredential.user?.uid ?? "",
          'username': '',
        });
      } else {
        print("Existing user, updating Firestore");
        final userDoc = query.docs.first;
        final data = userDoc.data();
        final updates = {
          'lastLogin': FieldValue.serverTimestamp(),
          'uid': userCredential.user?.uid ?? "",
          'contactAccount': false,
        };

        if (fcmToken != null) {
          final List<String> existingTokens = List<String>.from(
            data['fcmTokens'] ?? [],
          );
          if (!existingTokens.contains(fcmToken)) {
            updates['fcmTokens'] = FieldValue.arrayUnion([fcmToken]);
          }
        }

        if (data['notificationEnabled'] == null) {
          updates['notificationEnabled'] = true;
        }

        await collection.doc(userDoc.id).update(updates);
      }

      await AppPreference().setBool(PreferencesKey.loggedIn, true);
      await AppPreference().setBool(
        PreferencesKey.infoGathered,
        query.docs.isEmpty
            ? false
            : query.docs.first.data()['infoGathered'] ?? false,
      );
      await AppPreference().setString(PreferencesKey.userPhoneNumber, phone);
      await AppPreference().setString(
        cacheUserIDKey,
        userCredential.user?.uid ?? "",
      );
      print("Preferences updated");

      Get.off(
        () =>
            query.docs.isEmpty ||
                    !(query.docs.first.data()['infoGathered'] ?? false)
                ? InfoGatheringScreen(userPhoneNumber: phone)
                : NavigationBarCustom(userPhoneNumber: phone),
      );
    } catch (e, stackTrace) {
      print("Error in _signInWithCredential: $e\n$stackTrace");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    }
  }

  final defaultPinTheme = PinTheme(
    width: 56,
    height: 64,
    decoration: BoxDecoration(
      color: Colors.grey,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.transparent),
    ),
  );
  var borderColor = Colors.grey;
  var errorColor = Color.fromRGBO(255, 234, 238, 1);

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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Column(
                          children: [
                            const Text(
                              "WELCOME TO MORAL 1",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16 * 2),
                            Row(
                              children: [
                                const Spacer(),
                                Expanded(
                                  flex: 8,
                                  child: SvgPicture.asset("assets/chat.svg"),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 16 * 2),
                          ],
                        ),
                        Row(
                          children: [
                            const Spacer(),
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_otpSent)
                                    Text(
                                      "Enter Otp",
                                      style: TextStyle(
                                        color: black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  if (_otpSent) const SizedBox(height: 20),
                                  if (_otpSent)
                                    Pinput(
                                      controller: _otpController,
                                      length: 6,
                                      focusedPinTheme: defaultPinTheme.copyWith(
                                        width: 56,
                                        height: 64,
                                        decoration: defaultPinTheme.decoration!
                                            .copyWith(
                                              border: Border.all(
                                                color: Color(0xFF6F35A5),
                                              ),
                                              color: white,
                                            ),
                                      ),
                                      errorPinTheme: defaultPinTheme.copyWith(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onCompleted: (otp) {
                                        _verifyOtp(otp);
                                      },
                                    ),
                                  if (_otpSent)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _otpSent = false;
                                          _otpController.clear();
                                          _mobileNumberController.clear();
                                        });
                                      },
                                      child: Text("Change Phone Number"),
                                    ),
                                  if (!_otpSent)
                                    Text(
                                      "Enter your mobile number",
                                      style: TextStyle(
                                        color: black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  if (!_otpSent) SizedBox(height: 10),
                                  if (!_otpSent)
                                    Form(
                                      key: _formKeyMobileNumber,
                                      child: IntlPhoneField(
                                        cursorColor: Colors.red,
                                        dropdownIconPosition:
                                            IconPosition.trailing,
                                        flagsButtonPadding:
                                            const EdgeInsets.only(left: 12),
                                        dropdownIcon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                        controller: _mobileNumberController,
                                        onCountryChanged: (country) {
                                          _mobileNumberController.clear();
                                        },
                                        decoration: InputDecoration(
                                          hintText: "Phone Number",
                                          counterText: '',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.blueGrey,
                                              width: 2.0,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.red,
                                              width: 2.0,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                borderSide: BorderSide(
                                                  color: Colors.red,
                                                  width: 2.0,
                                                ),
                                              ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                        textAlign: TextAlign.start,
                                        validator: (phone) {
                                          if (phone == null ||
                                              phone.number.isEmpty) {
                                            return "Phone number is required";
                                          } else if (phone.number.length < 10) {
                                            return "Phone number is too short";
                                          }
                                          return null;
                                        },
                                        initialCountryCode: 'IN',
                                        autovalidateMode:
                                            AutovalidateMode.always,
                                        onSaved: (phone) {
                                          phoneNumber.value =
                                              phone?.completeNumber ?? "";
                                        },
                                        onChanged: (phone) {
                                          phoneNumber.value =
                                              phone.completeNumber;
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_otpSent) {
                                        _verifyOtp(_otpController.text.trim());
                                      } else {
                                        if (_formKeyMobileNumber.currentState!
                                            .validate()) {
                                          _sendOtp();
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      backgroundColor: const Color(0xFF6F35A5),
                                      // backgroundColor: const Color(0xFFF1E6FF),
                                      shape: const StadiumBorder(),
                                      maximumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_isLoading)
                                          const Center(
                                            child: CupertinoActivityIndicator(
                                              radius: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        SizedBox(width: 10),
                                        Text(
                                          !_otpSent
                                              ? "Send Otp"
                                              : "Sign In".toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ],
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
