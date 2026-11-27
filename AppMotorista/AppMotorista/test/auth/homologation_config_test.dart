import 'dart:convert';

import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/core/config/app_config.dart';
import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/core/network/http_api_transport.dart';
import 'package:app_motorista/storage/secure_session_storage.dart';
import 'package:app_motorista/viagens/repositories/trips_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const legacyKey = AppConfig.legacySessionStorageKey;
  const homologationKey = AppConfig.homologationSessionStorageKey;

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('homologacao somente leitura seleciona chave exclusiva', () {
    const config = AppConfig(
      environment: 'homologacao',
      baseUri: 'https://motorista.parmatech.com.br',
      requestTimeout: Duration(seconds: 20),
      readOnly: true,
    );

    expect(config.sessionStorageKey, startsWith('${homologationKey}_'));
    expect(config.enableMobileBootstrap, isTrue);
  });

  test('homologacao com operacoes liberadas reutiliza a chave exclusiva', () {
    const config = AppConfig(
      environment: 'homologacao',
      baseUri: 'https://motorista.parmatech.com.br',
      requestTimeout: Duration(seconds: 20),
      readOnly: false,
    );

    expect(config.enableMobileBootstrap, isTrue);
    expect(config.sessionStorageKey, startsWith('${homologationKey}_'));
  });

  test('modo normal conserva chave legada', () {
    const config = AppConfig(
      environment: 'desenvolvimento',
      baseUri: 'http://10.0.2.2:5055',
      requestTimeout: Duration(seconds: 20),
    );

    expect(config.sessionStorageKey, startsWith('${legacyKey}_'));
    expect(config.enableMobileBootstrap, isFalse);
  });

  test('sessao de homologacao nao le, apaga ou sobrescreve a legada', () async {
    const legacyConfig = AppConfig(
      environment: 'desenvolvimento',
      baseUri: 'http://10.0.2.2:5055',
      requestTimeout: Duration(seconds: 20),
    );
    const homologationConfig = AppConfig(
      environment: 'homologacao',
      baseUri: 'https://motorista.parmatech.com.br',
      requestTimeout: Duration(seconds: 20),
    );
    final legacy = FlutterSecureSessionStorage(
      sessionKey: legacyConfig.sessionStorageKey,
    );
    final homologation = FlutterSecureSessionStorage(
      sessionKey: homologationConfig.sessionStorageKey,
    );
    await legacy.write(_session('legado'));

    expect(await homologation.read(), isNull);
    await homologation.write(_session('homologacao'));
    await homologation.clear();

    expect((await legacy.read())!.accessToken, 'legado');
    expect(await homologation.read(), isNull);
  });

  test('URL de homologacao e contrato de lista sao enviados a Nuvem', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'contrato_versao': 1,
          'viagens': [
            {
              'manifesto_guid': 'MANIFEST-531',
              'carga': 531,
              'descricao': 'APP MOTORISTA',
              'quantidade_paradas': 1,
              'quantidade_ocorrencias': 4,
            },
          ],
        }),
        200,
      );
    });
    final repository = TripsRepository(
      ApiClient(
        transport: HttpApiTransport(
          baseUri: 'https://motorista.parmatech.com.br',
          timeout: const Duration(seconds: 20),
          client: client,
        ),
      ),
    );

    final trips = await repository.list('token-de-teste');

    expect(
      requested.toString(),
      'https://motorista.parmatech.com.br/api/v1/motorista/viagens',
    );
    expect(trips.single.loadId, 531);
  });
}

DriverSession _session(String token) => DriverSession(
  accessToken: token,
  refreshToken: '',
  accessExpiresAt: DateTime.utc(2030),
  driver: const DriverIdentity(guid: 'DRIVER', name: 'Motorista'),
);
