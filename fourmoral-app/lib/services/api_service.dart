// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:3000";

  Future<List<Map<dynamic, dynamic>>> getGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/groups'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<dynamic, dynamic>).toList();
    } else {
      throw Exception('Failed to load groups');
    }
  }
}