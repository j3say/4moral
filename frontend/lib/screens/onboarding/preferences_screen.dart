import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'profile_setup_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<String> communities = ["Spiritual", "Education", "Environment", "Social Work", "Meditation", "Philosophy", "Mental Health", "Yoga", "Charity", "Ethics"];
  final Set<String> selected = {};

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
            const Text("Choose communities", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Select areas of interest to personalize your feed and discover mentors.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  final item = communities[index];
                  final isSelected = selected.contains(item);
                  return GestureDetector(
                    onTap: () => setState(() => isSelected ? selected.remove(item) : selected.add(item)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                        border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Center(child: Text(item, style: TextStyle(color: isSelected ? Colors.blue : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500))),
                          if (isSelected) const Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: Colors.blue, size: 16)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: selected.length >= 2 
                  ? () => Get.to(() => ProfileSetupScreen(selectedCommunities: selected.toList())) 
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("Continue (${selected.length})", style: TextStyle(color: selected.length >= 2 ? Colors.white : Colors.grey)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}