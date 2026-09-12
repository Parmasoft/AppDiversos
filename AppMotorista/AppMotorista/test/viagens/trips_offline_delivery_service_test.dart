import 'dart:convert';
import 'dart:io';

import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/errors/api_exception.dart';
import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/core/network/api_transport.dart';
import 'package:app_motorista/core/network/http_api_transport.dart';
import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:app_motorista/viagens/local/delivery_local_store.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/repositories/trips_repository.dart';
import 'package:app_motorista/viagens/services/delivery_scanner_controller.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late AppDatabase appDatabase;
  late TripLocalStore tripStore;
  late OutboxLocalStore outboxStore;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-offline-delivery-',
    );
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path.join(temporaryDirectory.path, 'offline.db'),
    );
    tripStore = TripLocalStore(appDatabase);
    outboxStore = OutboxLocalStore(appDatabase);
    await tripStore.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(),
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
      lastServerSyncAt: DateTime.utc(2026, 8, 27, 12),
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('online envia e confirma exatamente o UUID persistido', () async {
    final transport = _RecordingTransport([
      _deliveryResponse(result: 'ACEITA', occurrenceGuid: 'OC-1'),
    ]);
    final service = await _service(
      transport: transport,
      operationGuids: ['11111111-1111-4111-8111-111111111111'],
      appDatabase: appDatabase,
      tripStore: tripStore,
    );

    final result = await service.registerRead(
      manifestGuid: 'MANIFEST-1',
      stopId: 20,
      orderId: 200,
      code: 'CODIGO-C',
    );

    expect(result.isAccepted, isTrue);
    expect(result.awaitingSync, isFalse);
    expect(transport.calls, 1);
    final sent = transport.bodies.single! as Map<String, Object>;
    expect(sent['operacao_guid'], '11111111-1111-4111-8111-111111111111');
    final operation = await outboxStore.find(
      '11111111-1111-4111-8111-111111111111',
    );
    expect(operation!.state, OutboxSyncState.synced);
    expect(operation.occurrenceGuid, 'OC-1');
    expect(jsonDecode(operation.payloadJson), sent);
  });

  test(
    'perda de resposta mantém sucesso local e o mesmo UUID pendente',
    () async {
      final transport = _RecordingTransport([
        const ApiException('conexão interrompida'),
      ]);
      final service = await _service(
        transport: transport,
        operationGuids: ['22222222-2222-4222-8222-222222222222'],
        appDatabase: appDatabase,
        tripStore: tripStore,
      );

      final result = await service.registerRead(
        manifestGuid: 'MANIFEST-1',
        stopId: 20,
        orderId: 200,
        code: 'CODIGO-C',
      );

      expect(result.responseCode, 'ACEITA_LOCAL');
      expect(result.awaitingSync, isTrue);
      final operation = await outboxStore.find(
        '22222222-2222-4222-8222-222222222222',
      );
      expect(operation!.state, OutboxSyncState.pending);
      expect(operation.attemptCount, 1);
      expect(operation.occurrenceGuid, 'OC-1');
      expect(
        (jsonDecode(operation.payloadJson) as Map)['operacao_guid'],
        operation.operationGuid,
      );
    },
  );

  test(
    'API inacessível após abrir snapshot aceita leitura local sem tentar POST',
    () async {
      final methods = <String>[];
      final transport = HttpApiTransport(
        baseUri: 'http://127.0.0.1:5055',
        timeout: const Duration(seconds: 1),
        client: MockClient((request) async {
          methods.add(request.method);
          throw http.ClientException(
            'Sem conexão com o servidor.',
            request.url,
          );
        }),
      );
      final service = await _service(
        transport: transport,
        operationGuids: ['55555555-5555-4555-8555-555555555555'],
        appDatabase: appDatabase,
        tripStore: tripStore,
      );

      final savedTrip = await service.get('MANIFEST-1');
      expect(service.tripUsesSavedData('MANIFEST-1'), isTrue);
      final stop = savedTrip.stops.single;
      final controller = DeliveryScannerController(
        gateway: service,
        manifestGuid: savedTrip.manifestGuid,
        stopId: stop.id,
        order: stop.orders.single,
        occurrences: stop.occurrences,
      );

      final status = await controller.submit('CODIGO-C');

      expect(status, ScanSubmitStatus.sent);
      expect(controller.feedback!.kind, DeliveryFeedbackKind.success);
      expect(
        controller.feedback!.message,
        contains('Aguardando sincronização'),
      );
      expect(controller.delivered, 1);
      expect(controller.pending, 1);
      expect(methods, ['GET']);
      final operation = await outboxStore.find(
        '55555555-5555-4555-8555-555555555555',
      );
      expect(operation!.state, OutboxSyncState.pending);
      expect(operation.attemptCount, 0);
      expect(operation.occurrenceGuid, 'OC-1');
      controller.dispose();
    },
  );

  test(
    'pendência anterior preserva ordem e não transmite a leitura nova',
    () async {
      final transport = _RecordingTransport([
        const ApiException('sem conexão'),
      ]);
      final service = await _service(
        transport: transport,
        operationGuids: [
          '33333333-3333-4333-8333-333333333331',
          '33333333-3333-4333-8333-333333333332',
        ],
        appDatabase: appDatabase,
        tripStore: tripStore,
      );

      await service.registerRead(
        manifestGuid: 'MANIFEST-1',
        stopId: 20,
        orderId: 200,
        code: 'CODIGO-C',
      );
      final second = await service.registerRead(
        manifestGuid: 'MANIFEST-1',
        stopId: 20,
        orderId: 200,
        code: 'CODIGO-C',
      );

      expect(second.awaitingSync, isTrue);
      expect(second.pendingOrder, 0);
      expect(transport.calls, 1);
      final ready = await outboxStore.listReady(driverGuid: 'DRIVER-A');
      expect(ready.map((operation) => operation.operationGuid), [
        '33333333-3333-4333-8333-333333333331',
        '33333333-3333-4333-8333-333333333332',
      ]);
    },
  );

  test('recusa terminal do servidor reverte a mutação local', () async {
    final transport = _RecordingTransport([
      _deliveryResponse(result: 'RECUSADA', statusCode: 409),
    ]);
    final service = await _service(
      transport: transport,
      operationGuids: ['44444444-4444-4444-8444-444444444444'],
      appDatabase: appDatabase,
      tripStore: tripStore,
    );

    final result = await service.registerRead(
      manifestGuid: 'MANIFEST-1',
      stopId: 20,
      orderId: 200,
      code: 'CODIGO-C',
    );

    expect(result.result, 'RECUSADA');
    final snapshot = await tripStore.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );
    expect(snapshot!.stops.single.deliveredFor(200), 0);
    expect(snapshot.stops.single.pendingFor(200), 2);
    final operation = await outboxStore.find(
      '44444444-4444-4444-8444-444444444444',
    );
    expect(operation!.state, OutboxSyncState.rejected);
  });
}

Future<TripsService> _service({
  required ApiTransport transport,
  required List<String> operationGuids,
  required AppDatabase appDatabase,
  required TripLocalStore tripStore,
}) async {
  final sessionController = SessionController(
    repository: FakeAuthGateway(),
    storage: MemorySessionStorage(
      DriverSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessExpiresAt: DateTime.utc(2030),
        driver: const DriverIdentity(guid: 'DRIVER-A', name: 'Motorista'),
      ),
    ),
    now: () => DateTime.utc(2026, 8, 27, 12),
  );
  await sessionController.restore();
  return TripsService(
    repository: TripsRepository(ApiClient(transport: transport)),
    sessionController: sessionController,
    localStore: tripStore,
    deliveryLocalStore: DeliveryLocalStore(appDatabase),
    outboxLocalStore: OutboxLocalStore(appDatabase),
    operationGuid: () => operationGuids.removeAt(0),
    now: () => DateTime.utc(2026, 8, 27, 12),
  );
}

class _RecordingTransport implements ApiTransport {
  _RecordingTransport(this.results);

  final List<Object> results;
  final List<Object?> bodies = [];
  int calls = 0;

  @override
  Future<ApiResponse> send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    calls++;
    bodies.add(body);
    final result = results.removeAt(0);
    if (result is ApiResponse) return result;
    throw result;
  }
}

ApiResponse _deliveryResponse({
  required String result,
  int statusCode = 200,
  String? occurrenceGuid,
}) {
  return ApiResponse(
    statusCode: statusCode,
    body: jsonEncode({
      'resultado': result,
      'codigo_resposta': result == 'ACEITA' ? 'OK' : 'CODIGO_RECUSADO',
      'mensagem': result == 'ACEITA' ? 'Registrada.' : 'Recusada.',
      'ocorrencia_guid': occurrenceGuid,
      'tipo': 'C',
      'pedido': 200,
      'pendentes_pedido': result == 'ACEITA' ? 1 : 2,
      'pendentes_parada': result == 'ACEITA' ? 1 : 2,
      'replay': false,
    }),
  );
}

TripDetail _trip() {
  return const TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 527,
    description: 'VIAGEM TESTE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    occurrenceCount: 2,
    stops: [
      TripStop(
        id: 20,
        plannedOrder: 1,
        status: 'P',
        clientName: 'CLIENTE',
        city: 'UBÁ',
        state: 'MG',
        address: '',
        orders: [TripOrder(id: 200, status: 'P')],
        occurrences: [
          ManifestOccurrence(
            id: 1,
            guid: 'OC-1',
            orderId: 200,
            productId: 10,
            type: 'C',
            code: 'CODIGO-C',
            quantity: '1',
            status: 'P',
          ),
          ManifestOccurrence(
            id: 2,
            guid: 'OC-2',
            orderId: 200,
            productId: 10,
            type: 'C',
            code: 'CODIGO-C',
            quantity: '1',
            status: 'P',
          ),
        ],
      ),
    ],
  );
}
