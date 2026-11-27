import 'package:app_motorista/core/config/admin_access_store.dart';
import 'package:app_motorista/core/config/api_endpoint.dart';
import 'package:app_motorista/core/config/api_endpoint_store.dart';
import 'package:app_motorista/core/config/app_config.dart';
import 'package:app_motorista/core/network/api_health_checker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('endpoint HTTPS normaliza e rejeita HTTP em homologação', () {
    expect(
      ApiEndpoint.parse(
        'https://motorista.parmatech.com.br/',
        allowHttp: false,
      ).baseUri,
      'https://motorista.parmatech.com.br',
    );
    expect(
      () => ApiEndpoint.parse('http://10.0.2.2:5055', allowHttp: false),
      throwsFormatException,
    );
  });

  test('endpoint salvo permanece disponível na próxima abertura', () async {
    final store = SecureApiEndpointStore();
    await store.write(const ApiEndpoint('https://motorista.parmatech.com.br'));
    final restored = await store.read(allowHttp: false);
    expect(restored!.baseUri, 'https://motorista.parmatech.com.br');
  });

  test('troca de servidor usa escopos distintos para sessão e cache local', () {
    const first = AppConfig(
      environment: 'homologacao',
      baseUri: 'https://motorista.parmatech.com.br',
      requestTimeout: Duration(seconds: 20),
    );
    const second = AppConfig(
      environment: 'homologacao',
      baseUri: 'https://outro-servidor.exemplo',
      requestTimeout: Duration(seconds: 20),
    );
    expect(first.sessionStorageKey, isNot(second.sessionStorageKey));
    expect(first.storageScope, isNot(second.storageScope));
  });

  test(
    'senha administrativa provisória pode ser substituída sem recompilar',
    () async {
      final access = AdminAccessStore();
      expect(await access.verify('123'), isTrue);
      expect(
        await access.changePassword(
          currentPassword: '123',
          newPassword: 'nova-senha',
        ),
        isTrue,
      );
      expect(await access.verify('123'), isFalse);
      expect(await access.verify('nova-senha'), isTrue);
    },
  );

  test('health usa endpoint público sem autenticação', () async {
    Uri? requested;
    final checker = ApiHealthChecker(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    final result = await checker.check('https://motorista.parmatech.com.br');
    expect(result.ok, isTrue);
    expect(
      requested.toString(),
      'https://motorista.parmatech.com.br/api/v1/health',
    );
  });
}
