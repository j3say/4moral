import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../onboarding/terms_conditions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller to capture and validate input
  final TextEditingController _phoneController = TextEditingController();

  void _handleContinue() {
    String phone = _phoneController.text.trim();

    // 1. Check if empty
    if (phone.isEmpty) {
      Get.snackbar(
        "Required", 
        "Please enter your mobile number",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    // 2. Validate exactly 10 digits using Regex
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      Get.snackbar(
        "Invalid Number", 
        "Please enter a valid 10-digit mobile number",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    // 3. If valid, proceed to the next screen
    Get.to(() => const TermsConditionsScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("4Moral", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text("Enter your phone number to continue.", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone, // Opens numeric keyboard
                      maxLength: 10, // Visual limit for the user
                      decoration: InputDecoration(
                        counterText: "", // Hides the default counter
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12), 
                          child: Text("+91 | ", style: TextStyle(fontWeight: FontWeight.bold))
                        ),
                        hintText: "Phone number",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleContinue, // Triggers validation logic
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ),
                        child: const Text("Continue >", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "We will send an OTP to verify your number.", 
                        style: TextStyle(fontSize: 12, color: Colors.grey)
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}