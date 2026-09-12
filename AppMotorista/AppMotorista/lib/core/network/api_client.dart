import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../errors/api_exception.dart';
import 'api_transport.dart';

class ApiClient {
  const ApiClient({required ApiTransport transport}) : _transport = transport;

  final ApiTransport _transport;

  Future<Map<String, dynamic>> getJson(String path, {String? accessToken}) {
    return _request('GET', path, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    String? accessToken,
    Set<int> acceptedStatusCodes = const {},
  }) {
    return _request(
      'POST',
      path,
      body: body,
      accessToken: accessToken,
      acceptedStatusCodes: acceptedStatusCodes,
    );
  }

  Future<Map<String, dynamic>> postPersistedJson(
    String path, {
    required String jsonBody,
    String? accessToken,
    Set<int> acceptedStatusCodes = const {},
  }) {
    return _request(
      'POST',
      path,
      body: RawJsonBody(jsonBody),
      accessToken: accessToken,
      acceptedStatusCodes: acceptedStatusCodes,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    String? accessToken,
    Set<int> acceptedStatusCodes = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _transport.send(
        method: method,
        path: path,
        body: body,
        headers: accessToken == null
            ? null
            : {'Authorization': 'Bearer $accessToken'},
      );
      final decoded = _decode(response.body);
      final isSuccessful =
          response.statusCode >= 200 && response.statusCode < 300;
      if (!isSuccessful && !acceptedStatusCodes.contains(response.statusCode)) {
        throw ApiException(
          _friendlyMessage(response.statusCode, decoded),
          statusCode: response.statusCode,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('O servidor enviou uma resposta inválida.');
      }
      return decoded;
    } finally {
      if (kDebugMode) {
        debugPrint('$method $path (${stopwatch.elapsedMilliseconds} ms)');
      }
    }
  }

  Object? _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw ApiException(
        'O servidor enviou uma resposta inválida.',
        cause: error,
      );
    }
  }

  String _friendlyMessage(int statusCode, Object? decoded) {
    if (statusCode == 401) return 'Sua sessão expirou. Entre novamente.';
    if (statusCode == 403) return 'Você não tem acesso a esta viagem.';
    if (statusCode == 404) return 'A informação solicitada não foi encontrada.';
    if (statusCode >= 500) {
      return 'O servidor está indisponível. Tente novamente.';
    }
    if (decoded case {'erro': final String message} when message.isNotEmpty) {
      return message;
    }
    return 'Não foi possível concluir a operação.';
  }
}
