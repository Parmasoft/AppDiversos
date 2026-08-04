import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'Erro $statusCode: $message';
}

class ApiService {
  // 🔹 POST JSON PADRONIZADO
  static Future<dynamic> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final resp = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    validarResposta(resp);
    return _decode(resp);
  }

  // 🔹 GET JSON PADRONIZADO (para uso futuro)
  //static Future<Map<String, dynamic>> get(String url) async {
  static Future<dynamic> get(String url) async {
    final resp = await http.get(Uri.parse(url));
    validarResposta(resp);
    return _decode(resp);
  }

  // 🔐 VALIDAÇÃO CENTRAL
  static void validarResposta(http.Response resp) {
    if (resp.statusCode == 200) return;

    String mensagem = 'Erro desconhecido';

    try {
      final body = jsonDecode(resp.body);
      if (body is Map) {
        if (body['erro'] != null) mensagem = body['erro'];
        if (body['message'] != null) mensagem = body['message'];
      }
    } catch (_) {}

    throw ApiException(resp.statusCode, mensagem);
  }

  //static Map<String, dynamic> _decode(http.Response resp) {
  //  if (resp.body.isEmpty) return {};
  //  return jsonDecode(resp.body);
  //}
  static dynamic _decode(http.Response resp) {
    if (resp.body.isEmpty) return null;
    return jsonDecode(resp.body);
  }
}
