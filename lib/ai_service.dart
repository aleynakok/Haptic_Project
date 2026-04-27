import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String baseUrl = "https://haptic-project-ai.onrender.com";
  final String apiUrl  = "https://haptic-project-ai.onrender.com/predict";

  Future<String> predictFabric(String url) async {
    print("Server is waking up...");

    try {
      await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 60));
      print("Server is awake.");
    } catch (_) {
      print("Ping failed, but it's still being tried....");
    }

    print("Sending request: $url");
    try {
      final response = await http
          .post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": url}),
      )
          .timeout(const Duration(seconds: 30));

      print("The answer came: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fabric_type'] ?? "Fabric Unidentified";
      } else {
        return "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      print("Connection Error Details: $e");
      return "Connection could not be established. Is the server online?";
    }
  }
}
