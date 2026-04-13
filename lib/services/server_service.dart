import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class HapticServer {
  // Bu fonksiyon senin Bluetooth ile veri gönderen ana fonksiyonun olacak
  final Function(String) onDataReceived;

  HapticServer({required this.onDataReceived});

  Future<void> startServer() async {
    final router = Router();

    // Uzantıdan gelen POST isteğini karşılayan yer:
    router.post('/feel', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      String material = data['material'];

      print("Uzantıdan mesaj geldi: $material");

      // Flutter arayüzüne veya Bluetooth servisine haber veriyoruz
      onDataReceived(material);

      // Tarayıcıya "Tamam, aldım" diyoruz (CORS ayarlarıyla birlikte)
      return Response.ok(
        jsonEncode({'status': 'success'}),
        headers: {
          'Access-Control-Allow-Origin': '*', // Tarayıcı engellememesi için kritik!
          'Content-Type': 'application/json',
        },
      );
    });

    // Options isteği (Tarayıcılar güvenlik için önce bunu sorar)
    router.all('/<ignored|.*>', (Request request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      }
      return Response.notFound('Not Found');
    });

    var server = await io.serve(router, '127.0.0.1', 8080);
    print('Server http://${server.address.address}:${server.port} adresinde dinliyor.');
  }
}