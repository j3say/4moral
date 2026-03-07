import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'community_guidelines_screen.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text("User Agreement", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF5F7F9), borderRadius: BorderRadius.circular(16)),
                child: const SingleChildScrollView(
                  child: Text(
                    "1. Acceptance of Terms\nBy accessing or using 4Moral, you agree to be bound by these Terms. If you disagree with any part of the terms, you may not access the service.\n\n"
                    "2. Community Standards\n4Moral is a platform for meaningful, moral, and philosophical connection. Hate speech, bullying, or inappropriate content will result in immediate termination of your account.\n\n"
                    "3. Privacy & Data\nWe respect your privacy. Your data is encrypted and never sold to third parties. We only use your information to provide a better, more personalized experience.\n\n"
                    "4. Content Ownership\nYou retain all rights to the content you post. However, by posting, you grant us a license to display and distribute it within the platform.",
                    style: TextStyle(color: Colors.black54, height: 1.6, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F7F9), borderRadius: BorderRadius.circular(12)),
              child: CheckboxListTile(
                value: isAgreed,
                onChanged: (val) => setState(() => isAgreed = val!),
                title: const Text("I agree to the Terms and Privacy Policy", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.blue,
                contentPadding: EdgeInsets.zero,
                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isAgreed ? () => Get.to(() => const CommunityGuidelinesScreen()) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("Agree and Continue", style: TextStyle(color: isAgreed ? Colors.white : Colors.grey, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}