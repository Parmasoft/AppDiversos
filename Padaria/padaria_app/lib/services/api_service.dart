import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _kIpKey = 'api_ip';
  static const _kPortKey = 'api_port';

  static const String defaultIp = '192.168.0.250';
  static const String defaultPort = '5002';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get ip => _prefs.getString(_kIpKey) ?? defaultIp;
  static String get port => _prefs.getString(_kPortKey) ?? defaultPort;

  static String get baseUrl => 'http://$ip:$port';

  // Endpoints base (opcional, só pra facilitar leitura)
  static String get produtos => '$baseUrl/produtos';
  static String get recheios => '$baseUrl/recheios';
  static String get pedidos => '$baseUrl/pedidos';

  static Future<void> salvarConfig({
    required String ip,
    required String port,
  }) async {
    await _prefs.setString(_kIpKey, ip.trim());
    await _prefs.setString(_kPortKey, port.trim());
  }

  // ======================================================
  // ✅ MÉTODOS HTTP
  // ======================================================

  static Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final resp = await http.get(uri);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }

    throw Exception('Erro GET ${resp.statusCode}: ${resp.body}');
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    //print('POST => $baseUrl/imprimir/termico | data=$body');
    print('POST => $uri | body=$body');

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }

    throw Exception('Erro POST ${resp.statusCode}: ${resp.body}');
  }

  // ==================================================
  // UPLOAD FOTO DO PEDIDO (MULTIPART)
  // ==================================================
  static Future<void> uploadFotoPedido({
    required int pedidoId,
    required String fotoPathLocal,
  }) async {
    final uri = Uri.parse('$baseUrl/upload/pedido-foto');

    final request = http.MultipartRequest('POST', uri);
    request.fields['ped_id'] = pedidoId.toString();

    request.files.add(
      await http.MultipartFile.fromPath('foto', File(fotoPathLocal).path),
    );

    final resp = await request.send();

    if (resp.statusCode != 200) {
      throw Exception(
        'Erro ao enviar foto do pedido (HTTP ${resp.statusCode})',
      );
    }
  }
}
