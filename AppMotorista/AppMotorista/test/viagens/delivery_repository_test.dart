import 'dart:convert';

import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/core/network/api_transport.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:app_motorista/viagens/repositories/trips_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test('envia leitura ao endpoint oficial com os campos do contrato', () async {
    final transport = FakeApiTransport()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body: '''{
            "resultado":"ACEITA",
            "codigo_resposta":"OK",
            "mensagem":"Entrega registrada.",
            "operacao":91,
            "ocorrencia_guid":"OC-GUID",
            "tipo":"C",
            "pedido":123,
            "pendentes_pedido":2,
            "pendentes_parada":5,
            "replay":false
          }''',
        ),
      );
    final repository = TripsRepository(ApiClient(transport: transport));
    final date = DateTime.parse('2026-08-26T14:30:00-03:00');

    final result = await repository.registerRead(
      manifestGuid: 'MANIFESTO',
      stopId: 7,
      orderId: 123,
      operationGuid: 'OP-GUID',
      code: 'ETIQUETA',
      deviceDateTime: date,
      timezoneOffsetMinutes: -180,
      accessToken: 'ACCESS',
    );

    expect(transport.lastMethod, 'POST');
    expect(
      transport.lastPath,
      '/api/v1/motorista/viagens/MANIFESTO/paradas/7/'
      'pedidos/123/leituras',
    );
    expect(transport.lastHeaders, {'Authorization': 'Bearer ACCESS'});
    expect(transport.lastBody, {
      'operacao_guid': 'OP-GUID',
      'codigo': 'ETIQUETA',
      'data_hora_aparelho': date.toIso8601String(),
      'fuso_minutos': -180,
    });
    expect(result.isAccepted, isTrue);
    expect(result.occurrenceGuid, 'OC-GUID');
  });

  test('interpreta conflito HTTP 409 como resposta funcional', () async {
    final transport = FakeApiTransport()
      ..responses.add(
        const ApiResponse(
          statusCode: 409,
          body: '''{
            "resultado":"CONFLITO",
            "codigo_resposta":"OPERACAO_CONFLITANTE",
            "mensagem":"Operação já usada com outro conteúdo.",
            "replay":true
          }''',
        ),
      );
    final repository = TripsRepository(ApiClient(transport: transport));

    final result = await repository.registerRead(
      manifestGuid: 'MANIFESTO',
      stopId: 7,
      orderId: 123,
      operationGuid: 'OP-GUID',
      code: 'ETIQUETA',
      deviceDateTime: DateTime(2026, 8, 26),
      timezoneOffsetMinutes: -180,
      accessToken: 'ACCESS',
    );

    expect(result.isConflict, isTrue);
    expect(result.message, contains('outro conteúdo'));
  });

  test('reenvia literalmente o payload JSON persistido na outbox', () async {
    final transport = FakeApiTransport()
      ..responses.add(
        const ApiResponse(
          statusCode: 200,
          body: '''{
            "resultado":"ACEITA",
            "codigo_resposta":"REPLAY",
            "mensagem":"Operação já processada.",
            "ocorrencia_guid":"OC-GUID",
            "replay":true
          }''',
        ),
      );
    final repository = TripsRepository(ApiClient(transport: transport));
    const payload =
        '{"operacao_guid":"OP-GUID","codigo":"ETIQUETA",'
        '"data_hora_aparelho":"2026-08-26T14:30:00-03:00",'
        '"fuso_minutos":-180}';
    final operation = OutboxOperation(
      operationGuid: 'OP-GUID',
      operationType: 'delivery_read',
      payloadVersion: 1,
      driverGuid: 'DRIVER-GUID',
      manifestGuid: 'MANIFESTO',
      occurrenceGuid: 'OC-GUID',
      stopId: 7,
      orderId: 123,
      code: 'ETIQUETA',
      deviceDateTime: DateTime.utc(2026, 8, 26, 17, 30),
      timezoneOffsetMinutes: -180,
      payloadJson: payload,
      state: OutboxSyncState.pending,
      attemptCount: 0,
      createdAt: DateTime.utc(2026, 8, 26, 17, 30),
    );

    final result = await repository.registerPersistedRead(
      operation: operation,
      accessToken: 'ACCESS',
    );

    expect(transport.lastBody, isA<RawJsonBody>());
    expect((transport.lastBody! as RawJsonBody).value, payload);
    expect(jsonDecode(payload)['operacao_guid'], operation.operationGuid);
    expect(result.isAccepted, isTrue);
    expect(result.replay, isTrue);
  });
}
