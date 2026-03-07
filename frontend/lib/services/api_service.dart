import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';

class ApiService {
  static const String baseUrl = "http://localhost:3000/api";
  final _storage = GetStorage();

  Map<String, String> _getHeaders() {
    String? token = _storage.read('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Authentication
  Future<Map<String, dynamic>> register(String mobileNumber, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mobileNumber': mobileNumber, 'password': password}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login(String mobileNumber, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mobileNumber': mobileNumber, 'password': password}),
    );
    return _handleResponse(response);
  }

  // 2. Profile Update (Matches router.put('/profile'))
  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
    String? age,
    String? community,
    File? imageFile,
  }) async {
    var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/users/profile'));
    
    String? token = _storage.read('jwt_token');
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (username != null) request.fields['username'] = username;
    if (bio != null) request.fields['bio'] = bio;
    if (age != null) request.fields['age'] = age;
    if (community != null) request.fields['community'] = community;

    if (imageFile != null) {
      // Key must be 'profileImage' to match your middleware
      request.files.add(await http.MultipartFile.fromPath('profileImage', imageFile.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // 3. User Identity
  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(Uri.parse('$baseUrl/users/me'), headers: _getHeaders());
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['token'] != null) _storage.write('jwt_token', data['token']);
      return data;
    } else {
      throw Exception(data['message'] ?? 'Request failed');
    }
  }
}