import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'profile_setup_screen.dart';
import 'preferences_screen.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Community Guidelines")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.gavel_rounded, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text("Our Standards", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              "• Be Respectful: Treat others with dignity.\n"
              "• No Harassment: Bullying is strictly prohibited.\n"
              "• Authentic Identity: Use your real name or a respectful alias.",
              textAlign: TextAlign.start,
              style: TextStyle(fontSize: 16, height: 2),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Get.to(() => const PreferencesScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("I Understand", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}