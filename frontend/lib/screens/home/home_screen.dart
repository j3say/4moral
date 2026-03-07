import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../profile/profile_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("4Moral", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Get.to(() => const ProfilePage()),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text("Welcome to your Feed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text("Content matching your preferences will appear here.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}