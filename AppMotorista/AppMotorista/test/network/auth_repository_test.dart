import 'package:app_motorista/auth/repositories/auth_repository.dart';
import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/core/network/api_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test('login usa o contrato oficial e interpreta a sessão', () async {
    final transport = FakeApiTransport()
      ..responses.add(
        const ApiResponse(
          statusCode: 201,
          body: '''{
            "access_token":"access",
            "refresh_token":"refresh",
            "access_expires_at":"2026-08-25T16:00:00",
            "motorista":{"guid":"GUID","nome":"Jorge"}
          }''',
        ),
      );
    final repository = AuthRepository(ApiClient(transport: transport));

    final result = await repository.login(
      username: 'jorge',
      password: 'segredo',
      device: 'celular',
    );

    expect(transport.lastMethod, 'POST');
    expect(transport.lastPath, '/api/v1/motorista/sessoes');
    expect(transport.lastBody, {
      'login': 'jorge',
      'senha': 'segredo',
      'dispositivo': 'celular',
    });
    expect(result.driver.name, 'Jorge');
    expect(result.accessToken, 'access');
  });
}
