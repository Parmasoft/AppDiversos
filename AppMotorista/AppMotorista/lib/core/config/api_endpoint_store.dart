import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_endpoint.dart';

abstract interface class ApiEndpointStore {
  Future<ApiEndpoint?> read({required bool allowHttp});
  Future<void> write(ApiEndpoint endpoint);
}

class SecureApiEndpointStore implements ApiEndpointStore {
  SecureApiEndpointStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'motorista_api_endpoint_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ApiEndpoint?> read({required bool allowHttp}) async {
    final value = await _storage.read(key: _key);
    if (value == null || value.isEmpty) return null;
    try {
      return ApiEndpoint.parse(value, allowHttp: allowHttp);
    } on FormatException {
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(ApiEndpoint endpoint) =>
      _storage.write(key: _key, value: endpoint.baseUri);
}
