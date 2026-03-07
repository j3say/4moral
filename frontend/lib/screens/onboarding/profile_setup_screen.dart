import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  // Receive selected communities from the previous PreferencesScreen
  final List<String> selectedCommunities;

  const ProfileSetupScreen({super.key, required this.selectedCommunities});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final api = ApiService();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController(); // Added age field
  
  File? _image;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  // YOUR REQUESTED LOGIC ADDED HERE
void _handleContinue() async {
  if (_usernameController.text.isEmpty || _ageController.text.isEmpty) {
    Get.snackbar("Error", "Username and Age are required");
    return;
  }

  setState(() => _isLoading = true);
  try {
    // 1. Join communities into a string for the MongoDB Schema
    String communitiesString = widget.selectedCommunities.join(', ');

    // 2. Call the PUT /api/users/profile endpoint
    await api.updateProfile(
      username: _usernameController.text,
      bio: _bioController.text,
      age: _ageController.text, // Field visible in your UI
      community: communitiesString,
      imageFile: _image,
    );

    // 3. Navigate to Home after successful update
    Get.offAll(() => const HomeScreen());
  } catch (e) {
    // This will catch the 'Failed to fetch' if CORS isn't fixed yet
    Get.snackbar("Connection Error", "Check if backend is running on Port 3000");
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Text("Complete Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text("Let the community know you.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
            // Image Picker UI
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60, 
                    backgroundColor: const Color(0xFFE3F2FD), 
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null ? const Icon(Icons.person_add_outlined, size: 40, color: Colors.blue) : null,
                  ),
                  const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 18, backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, size: 18, color: Colors.white))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            TextField(controller: _usernameController, decoration: InputDecoration(labelText: "Username", hintText: "@yourname", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),
            
            // Age Field integrated as required by your Backend Schema
            TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Age", hintText: "Enter your age", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),
            
            TextField(controller: _bioController, maxLines: 4, decoration: InputDecoration(labelText: "Bio (Optional)", hintText: "Share a little about yourself...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Continue", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}