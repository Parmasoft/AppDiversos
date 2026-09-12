import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/models/session.dart';
import 'session_storage.dart';

class FlutterSecureSessionStorage implements SessionStorage {
  FlutterSecureSessionStorage({
    FlutterSecureStorage? storage,
    String sessionKey = defaultSessionKey,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _sessionKey = sessionKey;

  static const defaultSessionKey = 'motorista_session_v1';
  final FlutterSecureStorage _storage;
  final String _sessionKey;

  @override
  Future<DriverSession?> read() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      return DriverSession.fromJson(decoded);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(DriverSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
