import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String baseUrl = "https://haptic-project-ai.onrender.com";
  final String apiUrl  = "https://haptic-project-ai.onrender.com/predict";

  Future<String> predictFabric(String url) async {
    print("Sunucu uyandırılıyor...");

    try {
      await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 60));
      print("Sunucu uyanık.");
    } catch (_) {
      print("Ping başarısız, yine de deneniyor...");
    }

    print("İstek gönderiliyor: $url");
    try {
      final response = await http
          .post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": url}),
      )
          .timeout(const Duration(seconds: 30));

      print("Cevap geldi: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fabric_type'] ?? "Kumaş Belirlenemedi";
      } else {
        return "Sunucu Hatası: ${response.statusCode}";
      }
    } catch (e) {
      print("Bağlantı Hatası Detayı: $e");
      return "Bağlantı kurulamadı. Sunucu açık mı?";
    }
  }
}
