import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Production URL for your deployed Render backend (Web Service)
  // REPLACE this with your actual Render service URL after creation (e.g. https://your-app.onrender.com)
  static const String _productionUrl = 'https://ultimate-rules-assistant.onrender.com';

  // Configured default local port for local development
  static const String _webLocalUrl = 'http://localhost:8000';
  static const String _androidLocalUrl = 'http://10.0.2.2:8000';

  String get baseUrl {
    // 1. If running in release/production build (Render static site)
    if (kReleaseMode) {
      return _productionUrl;
    }

    // 2. Otherwise use local development URLs
    try {
      // Simple runtime check for web browser vs mobile emulator
      if (identical(0, 0.0)) {
        return _webLocalUrl; // Web local development
      }
      return _webLocalUrl; // Default local fallback
    } catch (_) {
      return _webLocalUrl;
    }
  }

  /// Fetches the 10 pre-defined ultimate frisbee scenarios from the backend
  Future<List<Map<String, dynamic>>> fetchScenarios() async {
    final url = Uri.parse('$baseUrl/api/scenarios');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load scenarios (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to connect to RAG backend: $e');
    }
  }

  /// Queries the isolated RAG rulebook routing backend
  /// Passes [selectedLeagues] (1 or 2 leagues) and the [userQuery]
  Future<Map<String, dynamic>> queryRules(List<String> selectedLeagues, String userQuery) async {
    final url = Uri.parse('$baseUrl/api/query');
    final payload = {
      'selected_leagues': selectedLeagues,
      'user_query': userQuery,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 90)); // Generous timeout for RAG synthesis

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        final errorMsg = json.decode(response.body) ?? {};
        throw Exception(errorMsg['detail'] ?? 'RAG synthesis failed (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('RAG Query Connection Error: $e');
    }
  }
}
