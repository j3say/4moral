// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';

class ApiService {
  static const String baseUrl = "http://localhost:3000";
  final _storage = GetStorage();

  Map<String, String> _getHeaders() {
    String? token = _storage.read('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String mobileNumber, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mobileNumber': mobileNumber, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write('jwt_token', data['token']);
      return data;
    } else {
      throw Exception(json.decode(response.body)['message'] ?? 'Login Failed');
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['data'];
    } else if (response.statusCode == 401) {
      handleUnauthorized();
      throw Exception("Session Expired");
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  void handleUnauthorized() {
    _storage.remove('jwt_token'); 
    Get.offAllNamed('/login'); 
  }

  Future<List<Map<dynamic, dynamic>>> getGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups'),
      headers: _getHeaders(), 
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<dynamic, dynamic>).toList();
    } else {
      throw Exception('Failed to load groups');
    }
  }
}