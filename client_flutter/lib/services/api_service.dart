import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Uint8List?> generateNewsletter(
    String title,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/generate"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "content": content,
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    return null;
  }
}
