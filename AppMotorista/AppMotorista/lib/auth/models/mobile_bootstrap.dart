import 'dart:convert';

import 'session.dart';

class MobileBootstrap {
  const MobileBootstrap._({
    required this.token,
    required this.refreshToken,
    required this.expiresAt,
    required this.driver,
  });

  static const prefix = 'motorista-bootstrap:v1:';

  final String token;
  final String refreshToken;
  final DateTime expiresAt;
  final DriverIdentity driver;

  factory MobileBootstrap.parse(String value, {required DateTime now}) {
    if (!value.startsWith(prefix)) {
      throw const FormatException('QR de homologacao invalido.');
    }
    final encoded = value.substring(prefix.length);
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final token = decoded['token']?.toString().trim() ?? '';
      final refreshToken = decoded['refresh_token']?.toString().trim() ?? '';
      final expiresAt = DateTime.parse(
        decoded['expires_at'].toString(),
      ).toUtc();
      final driver = DriverIdentity.fromJson(
        Map<String, dynamic>.from(decoded['motorista'] as Map),
      );
      if (token.isEmpty || refreshToken.isEmpty ||
          driver.guid.trim().isEmpty ||
          !expiresAt.isAfter(now.add(const Duration(seconds: 30)))) {
        throw const FormatException();
      }
      return MobileBootstrap._(
        token: token,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        driver: driver,
      );
    } on FormatException {
      throw const FormatException('QR de homologacao invalido ou expirado.');
    }
  }

  DriverSession toSession() => DriverSession(
    accessToken: token,
    refreshToken: refreshToken,
    accessExpiresAt: expiresAt,
    driver: driver,
  );
}
