import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy Data as requested
    const String dummyBio = "Exploring the intersection of ethics and technology. Philosophy enthusiast.";
    const int dummyAge = 24;
    const List<String> dummyPreferences = ["Philosophy", "Ethics", "Meditation"];

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.person, size: 50, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Bio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(dummyBio, style: TextStyle(color: Colors.black54)),
            const Divider(height: 40),
            
            // Age display
            _buildInfoRow(Icons.cake_outlined, "Age", "$dummyAge years"),
            const SizedBox(height: 16),
            
            // Preferences display
            const Text("My Interests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: dummyPreferences.map((pref) => Chip(
                label: Text(pref),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.blue),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}