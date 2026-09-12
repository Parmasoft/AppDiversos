import 'dart:convert';
import 'dart:io';

import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/errors/api_exception.dart';
import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/core/network/api_transport.dart';
import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:app_motorista/viagens/local/delivery_local_store.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/repositories/trips_repository.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late TripLocalStore localStore;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-offline-service-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = _database(databasePath);
    localStore = TripLocalStore(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'snapshot da API é persistido e continua íntegro após reabrir o banco',
    () async {
      final service = await _service(
        localStore: localStore,
        appDatabase: appDatabase,
        transport: _QueueTransport([_detailResponse(loadId: 527)]),
      );

      final downloaded = await service.get('MANIFEST-1');

      expect(downloaded.stops.map((stop) => stop.id), [20, 10]);
      expect(downloaded.stops.first.orders.map((order) => order.id), [
        200,
        201,
      ]);
      expect(downloaded.stops.first.occurrences.map((item) => item.guid), [
        'C-1',
        'C-2',
        'R-22',
      ]);
      expect(downloaded.stops.first.occurrences.last.rollId, 22);

      await appDatabase.close();
      appDatabase = _database(databasePath);
      localStore = TripLocalStore(appDatabase);
      final restored = await localStore.readSnapshot(
        driverGuid: 'DRIVER-A',
        manifestGuid: 'MANIFEST-1',
      );

      expect(restored, isNotNull);
      expect(restored!.loadId, 527);
      expect(restored.stops.map((stop) => stop.id), [20, 10]);
      expect(restored.stops.first.orders.map((order) => order.id), [200, 201]);
      expect(
        restored.stops.first.occurrences.where((item) => item.type == 'C'),
        hasLength(2),
      );
      expect(restored.stops.first.occurrences.last.rollId, 22);
    },
  );

  test(
    'modo somente leitura consulta API sem alterar outbox ou cache',
    () async {
      const operationGuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final outboxStore = OutboxLocalStore(appDatabase);
      await outboxStore.enqueue(
        OutboxOperation(
          operationGuid: operationGuid,
          operationType: 'delivery_read',
          payloadVersion: 1,
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-ANTERIOR',
          stopId: 1,
          orderId: 1,
          code: 'CODIGO-ANTERIOR',
          deviceDateTime: DateTime.utc(2026, 8, 27, 12),
          timezoneOffsetMinutes: 0,
          payloadJson: '{}',
          state: OutboxSyncState.pending,
          attemptCount: 0,
          createdAt: DateTime.utc(2026, 8, 27, 12),
        ),
      );
      final transport = _QueueTransport([
        _listResponse(),
        _detailResponse(loadId: 531),
      ]);
      final service = await _service(
        localStore: localStore,
        appDatabase: appDatabase,
        transport: transport,
        readOnly: true,
      );

      final trips = await service.list();
      final detail = await service.get('MANIFEST-1');

      expect(trips.single.loadId, 531);
      expect(detail.loadId, 531);
      expect(await outboxStore.find(operationGuid), isA<OutboxOperation>());
      expect(
        (await outboxStore.find(operationGuid))!.state,
        OutboxSyncState.pending,
      );
      expect(
        await localStore.readSnapshot(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
        ),
        isNull,
      );
      await expectLater(
        service.registerRead(
          manifestGuid: 'MANIFEST-1',
          stopId: 20,
          orderId: 200,
          code: 'CODIGO-C',
        ),
        throwsA(isA<ReadOnlyTripException>()),
      );
      expect(transport.results, isEmpty);
    },
  );

  test('falha remota retorna lista e detalhe salvos do motorista', () async {
    final online = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([_detailResponse(loadId: 527)]),
    );
    await online.get('MANIFEST-1');
    final offline = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([
        const ApiException('sem conexão'),
        const ApiException('sem conexão'),
      ]),
    );

    final trips = await offline.list();
    final trip = await offline.get('MANIFEST-1');

    expect(trips, hasLength(1));
    expect(trips.single.loadId, 527);
    expect(trips.single.stopCount, 2);
    expect(trip.loadId, 527);
    expect(offline.listUsesSavedData, isTrue);
    expect(offline.tripUsesSavedData('MANIFEST-1'), isTrue);
  });

  test('falha remota sem snapshot gera mensagem controlada', () async {
    final service = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([const ApiException('SocketException')]),
    );

    await expectLater(
      service.list(),
      throwsA(
        isA<OfflineTripUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('antes de usá-la offline'),
        ),
      ),
    );
  });

  test('falha durante atualização preserva o snapshot anterior', () async {
    final initial = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([_detailResponse(loadId: 527)]),
    );
    await initial.get('MANIFEST-1');
    final invalidUpdate = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([
        _detailResponse(loadId: 999, duplicateOccurrenceGuid: true),
      ]),
    );

    await expectLater(
      invalidUpdate.get('MANIFEST-1'),
      throwsA(isA<DatabaseException>()),
    );
    final restored = await localStore.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );

    expect(restored!.loadId, 527);
    expect(restored.occurrenceCount, 4);
  });

  test('motorista B não usa o snapshot salvo pelo motorista A', () async {
    final driverA = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([_detailResponse(loadId: 527)]),
    );
    await driverA.get('MANIFEST-1');
    final driverB = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([const ApiException('sem conexão')]),
      driverGuid: 'DRIVER-B',
    );

    await expectLater(
      driverB.list(),
      throwsA(isA<OfflineTripUnavailableException>()),
    );
  });

  test('403 autenticado não é mascarado pelo snapshot local', () async {
    final online = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([_detailResponse(loadId: 527)]),
    );
    await online.get('MANIFEST-1');
    final forbidden = await _service(
      localStore: localStore,
      appDatabase: appDatabase,
      transport: _QueueTransport([
        const ApiResponse(statusCode: 403, body: '{}'),
      ]),
    );

    await expectLater(
      forbidden.get('MANIFEST-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(forbidden.tripUsesSavedData('MANIFEST-1'), isFalse);
  });

  test(
    'reaplica leituras synced por GUID ao reabrir snapshot remoto defasado',
    () async {
      final outboxStore = OutboxLocalStore(appDatabase);
      await outboxStore.enqueue(
        _syncedRead(
          guid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
          confirmedOccurrenceGuid: 'C-1',
          occurrenceGuid: 'C-1',
        ),
      );
      await outboxStore.enqueue(
        _syncedRead(
          guid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
          confirmedOccurrenceGuid: 'C-2',
          occurrenceGuid: null,
        ),
      );
      final service = await _service(
        localStore: localStore,
        appDatabase: appDatabase,
        transport: _QueueTransport([
          _reconciliationDetailResponse(),
          _reconciliationDetailResponse(),
          _reconciliationDetailResponse(remoteAlreadyUpdated: true),
        ]),
      );

      final first = await service.get('MANIFEST-1');
      expect(first.stops.single.deliveredFor(200), 3);
      expect(first.stops.single.pendingFor(200), 1);
      expect(first.stops.single.status, 'P');
      expect(first.stops.single.orders.single.status, 'P');
      expect(
        first.stops.single.occurrences
            .where((item) => item.code == 'CODIGO-C-REPETIDO')
            .every((item) => item.isDelivered),
        isTrue,
      );

      final reopened = await service.get('MANIFEST-1');
      expect(reopened.stops.single.deliveredFor(200), 3);
      expect(reopened.stops.single.pendingFor(200), 1);
      expect(reopened.stops.single.status, 'P');
      expect(reopened.stops.single.orders.single.status, 'P');

      final updatedRemote = await service.get('MANIFEST-1');
      expect(updatedRemote.stops.single.deliveredFor(200), 3);
      expect(updatedRemote.stops.single.pendingFor(200), 1);

      await expectLater(
        DeliveryLocalStore(appDatabase).registerRead(
          operationGuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
          stopId: 20,
          orderId: 200,
          code: 'CODIGO-C-REPETIDO',
          deviceDateTime: DateTime.utc(2026, 8, 27, 13),
          timezoneOffsetMinutes: 0,
        ),
        throwsA(
          isA<LocalDeliveryRejection>().having(
            (error) => error.responseCode,
            'responseCode',
            'MULTIPLICIDADE_ESGOTADA',
          ),
        ),
      );
      expect(await outboxStore.listReady(driverGuid: 'DRIVER-A'), isEmpty);
    },
  );

  test('pending, sending e retry nao participam da reconciliacao synced', () async {
    final outboxStore = OutboxLocalStore(appDatabase);
    for (final state in [
      OutboxSyncState.pending,
      OutboxSyncState.sending,
      OutboxSyncState.retry,
    ]) {
      await outboxStore.enqueue(
        _syncedRead(
          guid: 'bbbbbbbb-bbbb-4bbb-8bbb-aaaaaaaaaaa${state.index}',
          confirmedOccurrenceGuid: 'C-1',
          occurrenceGuid: 'C-1',
          state: state,
        ),
      );
    }
    expect(
      await outboxStore.listSyncedDeliveryReads(
        driverGuid: 'DRIVER-A',
        manifestGuid: 'MANIFEST-1',
      ),
      isEmpty,
    );
  });
}

AppDatabase _database(String databasePath) {
  return AppDatabase(factory: databaseFactoryFfi, databasePath: databasePath);
}

Future<TripsService> _service({
  required TripLocalStore localStore,
  required AppDatabase appDatabase,
  required ApiTransport transport,
  String driverGuid = 'DRIVER-A',
  bool readOnly = false,
}) async {
  final sessionController = SessionController(
    repository: FakeAuthGateway(),
    storage: MemorySessionStorage(_session(driverGuid)),
    now: () => DateTime.utc(2026, 8, 27, 12),
  );
  await sessionController.restore();
  return TripsService(
    repository: TripsRepository(ApiClient(transport: transport)),
    sessionController: sessionController,
    localStore: localStore,
    deliveryLocalStore: DeliveryLocalStore(appDatabase),
    outboxLocalStore: OutboxLocalStore(appDatabase),
    now: () => DateTime.utc(2026, 8, 27, 12),
    readOnly: readOnly,
  );
}

DriverSession _session(String driverGuid) {
  return DriverSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    accessExpiresAt: DateTime.utc(2030),
    driver: DriverIdentity(guid: driverGuid, name: 'Motorista $driverGuid'),
  );
}

class _QueueTransport implements ApiTransport {
  _QueueTransport(this.results);

  final List<Object> results;

  @override
  Future<ApiResponse> send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = results.removeAt(0);
    if (result is ApiResponse) return result;
    throw result;
  }
}

ApiResponse _detailResponse({
  required int loadId,
  bool duplicateOccurrenceGuid = false,
}) {
  return ApiResponse(
    statusCode: 200,
    body: jsonEncode(
      _detailJson(
        loadId: loadId,
        duplicateOccurrenceGuid: duplicateOccurrenceGuid,
      ),
    ),
  );
}

ApiResponse _listResponse() {
  return ApiResponse(
    statusCode: 200,
    body: jsonEncode({
      'viagens': [
        {
          'manifesto_guid': 'MANIFEST-1',
          'carga': 531,
          'descricao': 'VIAGEM TESTE',
          'quantidade_paradas': 2,
          'quantidade_ocorrencias': 4,
        },
      ],
    }),
  );
}

OutboxOperation _syncedRead({
  required String guid,
  required String confirmedOccurrenceGuid,
  String? occurrenceGuid,
  OutboxSyncState state = OutboxSyncState.synced,
}) {
  return OutboxOperation(
    operationGuid: guid,
    operationType: 'delivery_read',
    payloadVersion: 1,
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
    occurrenceGuid: occurrenceGuid,
    stopId: 20,
    orderId: 200,
    code: 'CODIGO-C-REPETIDO',
    deviceDateTime: DateTime.utc(2026, 8, 27, 12),
    timezoneOffsetMinutes: 0,
    payloadJson: jsonEncode({'operacao_guid': guid, 'codigo': 'CODIGO-C-REPETIDO'}),
    state: state,
    attemptCount: 1,
    createdAt: DateTime.utc(2026, 8, 27, 12),
    syncedAt: state == OutboxSyncState.synced
        ? DateTime.utc(2026, 8, 27, 12, 1)
        : null,
    responseCode: state == OutboxSyncState.synced ? 'LEITURA_CONFIRMADA' : null,
    responseJson: state == OutboxSyncState.synced
        ? jsonEncode({'ocorrencia_guid': confirmedOccurrenceGuid})
        : null,
  );
}

ApiResponse _reconciliationDetailResponse({bool remoteAlreadyUpdated = false}) {
  return ApiResponse(
    statusCode: 200,
    body: jsonEncode({
      'manifesto': {'guid': 'MANIFEST-1', 'status': 'L'},
      'carga': {'id': 531, 'descricao': 'VIAGEM TESTE'},
      'motorista': {'nome': 'PAULO'},
      'origem': {'nome_fantasia': 'GRAMDECOR'},
      'quantidade_ocorrencias': 4,
      'paradas': [
        {
          'parada': 20,
          'ordem': {'planejada': 1},
          'status': 'P',
          'cliente': {'nome': 'CLIENTE'},
          'endereco': {'cidade': 'UBA', 'uf': 'MG'},
          'pedidos': [
            {'pedido': 200, 'status': 'P'},
          ],
          'ocorrencias': [
            _occurrenceJson(
              id: 1,
              guid: 'C-1',
              orderId: 200,
              status: remoteAlreadyUpdated ? 'E' : 'P',
            ),
            _occurrenceJson(
              id: 2,
              guid: 'C-2',
              orderId: 200,
              status: remoteAlreadyUpdated ? 'E' : 'P',
            ),
            _occurrenceJson(
              id: 3,
              guid: 'R-22',
              orderId: 200,
              type: 'R',
              rollId: 22,
              status: 'E',
            ),
            _occurrenceJson(
              id: 4,
              guid: 'C-4',
              orderId: 200,
              code: 'CODIGO-PENDENTE',
            ),
          ],
        },
      ],
    }),
  );
}

Map<String, Object?> _detailJson({
  required int loadId,
  required bool duplicateOccurrenceGuid,
}) {
  return {
    'manifesto': {'guid': 'MANIFEST-1', 'status': 'L'},
    'carga': {
      'id': loadId,
      'descricao': 'VIAGEM TESTE',
      'saida_data': '2026-08-27',
      'saida_hora': '08:30:00',
    },
    'motorista': {'nome': 'PAULO'},
    'origem': {'nome_fantasia': 'GRAMDECOR'},
    'quantidade_ocorrencias': 4,
    'paradas': [
      {
        'parada': 20,
        'ordem': {'planejada': 2},
        'status': 'P',
        'cliente': {'nome': 'CLIENTE DOIS'},
        'endereco': {'cidade': 'MURIAÉ', 'uf': 'MG'},
        'pedidos': [
          {'pedido': 200, 'status': 'P'},
          {'pedido': 201, 'status': 'P'},
        ],
        'ocorrencias': [
          _occurrenceJson(id: 1, guid: 'C-1', orderId: 200),
          _occurrenceJson(
            id: 2,
            guid: duplicateOccurrenceGuid ? 'C-1' : 'C-2',
            orderId: 200,
          ),
          _occurrenceJson(
            id: 3,
            guid: 'R-22',
            orderId: 201,
            type: 'R',
            rollId: 22,
          ),
        ],
      },
      {
        'parada': 10,
        'ordem': {'planejada': 1},
        'status': 'P',
        'cliente': {'nome': 'CLIENTE UM'},
        'endereco': {'cidade': 'UBÁ', 'uf': 'MG'},
        'pedidos': [
          {'pedido': 100, 'status': 'P'},
        ],
        'ocorrencias': [_occurrenceJson(id: 4, guid: 'C-4', orderId: 100)],
      },
    ],
  };
}

Map<String, Object?> _occurrenceJson({
  required int id,
  required String guid,
  required int orderId,
  String type = 'C',
  int? rollId,
  String status = 'P',
  String? code,
}) {
  return {
    'ocorrencia': id,
    'guid': guid,
    'pedido': orderId,
    'produto': 1000 + id,
    'tipo': type,
    'codigo': code ?? (type == 'C' ? 'CODIGO-C-REPETIDO' : 'ROLO-22'),
    'rolo_id': ?rollId,
    'quantidade': '1.0000',
    'status': status,
  };
}
