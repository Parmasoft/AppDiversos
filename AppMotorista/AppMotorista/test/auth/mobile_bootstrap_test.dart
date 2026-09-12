import 'dart:convert';

import 'package:app_motorista/auth/models/mobile_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap QR preserva bearer e cria sessao do motorista informado', () {
    final value = _payload(
      token: 'Token-Com-Caixa-9',
      expiresAt: DateTime.utc(2026, 9, 7, 15),
    );

    final bootstrap = MobileBootstrap.parse(
      value,
      now: DateTime.utc(2026, 9, 7, 12),
    );

    expect(bootstrap.toSession().accessToken, 'Token-Com-Caixa-9');
    expect(bootstrap.toSession().refreshToken, 'refresh-qr-9');
    expect(bootstrap.toSession().driver.guid, 'DRIVER-531');
  });

  test('bootstrap QR expirado e rejeitado', () {
    expect(
      () => MobileBootstrap.parse(
        _payload(token: 'token', expiresAt: DateTime.utc(2026, 9, 7, 12)),
        now: DateTime.utc(2026, 9, 7, 12),
      ),
      throwsFormatException,
    );
  });
}

String _payload({required String token, required DateTime expiresAt}) {
  final encoded = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'token': token,
        'refresh_token': 'refresh-qr-9',
        'expires_at': expiresAt.toIso8601String(),
        'motorista': {'guid': 'DRIVER-531', 'nome': 'Paulo'},
      }),
    ),
  );
  return '${MobileBootstrap.prefix}$encoded';
}
