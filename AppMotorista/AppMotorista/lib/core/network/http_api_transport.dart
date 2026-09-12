import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/api_exception.dart';
import 'api_transport.dart';

class HttpApiTransport implements ApiTransport {
  HttpApiTransport({
    required String baseUri,
    required this.timeout,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUri),
       _client = client ?? http.Client();

  final Uri _baseUri;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<ApiResponse> send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, _baseUri.resolve(path));
    request.headers.addAll({
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      ...?headers,
    });
    if (body != null) {
      request.body = switch (body) {
        RawJsonBody(:final value) => value,
        _ => jsonEncode(body),
      };
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);
      return ApiResponse(
        statusCode: streamed.statusCode,
        body: await streamed.stream.bytesToString(),
      );
    } on TimeoutException catch (error) {
      throw ApiException(
        'A conexão demorou demais. Tente novamente.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Sem conexão com o servidor. Verifique sua internet.',
        cause: error,
      );
    }
  }
}
