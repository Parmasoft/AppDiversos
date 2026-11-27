import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiHealthResult {
  const ApiHealthResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class ApiHealthChecker {
  ApiHealthChecker({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<ApiHealthResult> check(String baseUri) async {
    try {
      final response = await _client
          .get(Uri.parse(baseUri).resolve('/api/v1/health'))
          .timeout(timeout);
      if (response.statusCode != 200) {
        return ApiHealthResult(
          ok: false,
          message: 'O servidor respondeu HTTP ${response.statusCode}.',
        );
      }
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'ok') {
        return const ApiHealthResult(
          ok: true,
          message: 'Conexão com a API confirmada.',
        );
      }
      return const ApiHealthResult(
        ok: false,
        message: 'A API respondeu de forma inesperada.',
      );
    } on TimeoutException {
      return const ApiHealthResult(
        ok: false,
        message: 'A conexão demorou demais.',
      );
    } catch (_) {
      return const ApiHealthResult(
        ok: false,
        message: 'Não foi possível alcançar a API.',
      );
    }
  }
}
