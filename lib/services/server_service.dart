import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class HapticServer {
  final Function(String) onDataReceived;

  HapticServer({required this.onDataReceived});

  Future<void> startServer() async {
    final router = Router();

    router.post('/feel', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      String material = data['material'];

      print("A message arrived from the extension: $material");

      onDataReceived(material);

      return Response.ok(
        jsonEncode({'status': 'success'}),
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json',
        },
      );
    });

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
    print('Server is listening at http://${server.address.address}:${server.port}.');
  }
}