import 'dart:io';

import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:app_motorista/viagens/local/delivery_local_store.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late TripLocalStore tripStore;
  late DeliveryLocalStore deliveryStore;
  late OutboxLocalStore outboxStore;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-local-delivery-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = _database(databasePath);
    tripStore = TripLocalStore(appDatabase);
    deliveryStore = DeliveryLocalStore(appDatabase);
    outboxStore = OutboxLocalStore(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'C repetida consome uma ocorrência por vez e bloqueia excesso',
    () async {
      await _seed(tripStore, _trip());

      final first = await _read(deliveryStore, index: 1, code: 'codigo-c');
      final second = await _read(deliveryStore, index: 2, code: 'CODIGO-C');

      expect(first.occurrenceGuid, 'C-1');
      expect(second.occurrenceGuid, 'C-2');
      expect(first.pendingOrder, 3);
      expect(second.pendingOrder, 2);
      await expectLater(
        _read(deliveryStore, index: 3, code: 'CODIGO-C'),
        throwsA(
          isA<LocalDeliveryRejection>().having(
            (error) => error.responseCode,
            'responseCode',
            'MULTIPLICIDADE_ESGOTADA',
          ),
        ),
      );
      expect(await _outboxCount(appDatabase), 2);
      final snapshot = await _snapshot(tripStore);
      expect(
        snapshot.stops.first.occurrences.where(
          (item) => item.code == 'CODIGO-C' && item.isDelivered,
        ),
        hasLength(2),
      );
    },
  );

  test('R preserva ROLO_ID, persiste uma vez e bloqueia releitura', () async {
    await _seed(tripStore, _trip());

    final accepted = await _read(deliveryStore, index: 1, code: 'ROLO-22');

    expect(accepted.occurrenceGuid, 'R-22');
    final snapshot = await _snapshot(tripStore);
    final roll = snapshot.stops.first.occurrences.singleWhere(
      (item) => item.guid == 'R-22',
    );
    expect(roll.rollId, 22);
    expect(roll.isDelivered, isTrue);
    await expectLater(
      _read(deliveryStore, index: 2, code: 'ROLO-22'),
      throwsA(
        isA<LocalDeliveryRejection>().having(
          (error) => error.responseCode,
          'responseCode',
          'ROLO_JA_RECEPCIONADO',
        ),
      ),
    );
    expect(await _outboxCount(appDatabase), 1);
  });

  test('censuras de escopo e código não alteram snapshot nem outbox', () async {
    await _seed(tripStore, _trip());
    await tripStore.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _otherManifest(),
      downloadedAt: DateTime.utc(2026, 8, 27, 11),
    );

    final cases = [
      (code: 'OUTRO-PEDIDO', expected: 'OUTRO_PEDIDO'),
      (code: 'OUTRA-PARADA', expected: 'OUTRA_PARADA'),
      (code: 'OUTRA-CARGA', expected: 'OUTRA_CARGA'),
      (code: 'INEXISTENTE', expected: 'CODIGO_NAO_DISPONIVEL'),
    ];
    for (var index = 0; index < cases.length; index++) {
      final item = cases[index];
      await expectLater(
        _read(deliveryStore, index: index + 1, code: item.code),
        throwsA(
          isA<LocalDeliveryRejection>().having(
            (error) => error.responseCode,
            'responseCode',
            item.expected,
          ),
        ),
      );
    }

    expect(await _outboxCount(appDatabase), 0);
    final snapshot = await _snapshot(tripStore);
    expect(
      snapshot.stops
          .expand((stop) => stop.occurrences)
          .every((occurrence) => occurrence.isPending),
      isTrue,
    );
  });

  test(
    'seis de dez leituras e UUIDs sobrevivem e as quatro finais concluem',
    () async {
      await _seed(tripStore, _tenOccurrencesTrip());
      final originalGuids = <String>[];
      final originalPayloads = <String>[];
      for (var index = 1; index <= 6; index++) {
        final accepted = await _read(
          deliveryStore,
          index: index,
          code: 'C-DEZ',
          orderId: 900,
        );
        final operation = await outboxStore.find(accepted.operationGuid);
        originalGuids.add(operation!.operationGuid);
        originalPayloads.add(operation.payloadJson);
      }

      await appDatabase.close();
      appDatabase = _database(databasePath);
      tripStore = TripLocalStore(appDatabase);
      deliveryStore = DeliveryLocalStore(appDatabase);
      outboxStore = OutboxLocalStore(appDatabase);

      var snapshot = await _snapshot(tripStore);
      expect(snapshot.stops.single.deliveredFor(900), 6);
      expect(snapshot.stops.single.pendingFor(900), 4);
      final restored = await outboxStore.listReady(driverGuid: 'DRIVER-A');
      expect(restored.map((item) => item.operationGuid), originalGuids);
      expect(restored.map((item) => item.payloadJson), originalPayloads);

      for (var index = 7; index <= 10; index++) {
        await _read(deliveryStore, index: index, code: 'C-DEZ', orderId: 900);
      }
      snapshot = await _snapshot(tripStore);
      expect(snapshot.stops.single.deliveredFor(900), 10);
      expect(snapshot.stops.single.pendingFor(900), 0);
      expect(snapshot.stops.single.orders.single.status, 'E');
      expect(snapshot.stops.single.status, 'E');
      expect(await _outboxCount(appDatabase), 10);
      var summary = (await tripStore.listSnapshots(
        driverGuid: 'DRIVER-A',
      )).single;
      expect(summary.locallyCompleted, isTrue);
      expect(summary.awaitingSync, isTrue);
      expect(
        await outboxStore.pendingOrderIds(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
          stopId: 20,
        ),
        {900},
      );
      expect(
        await outboxStore.pendingStopIds(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
        ),
        {20},
      );

      final operations = await outboxStore.listReady(driverGuid: 'DRIVER-A');
      for (final operation in operations) {
        await deliveryStore.finishAccepted(
          operationGuid: operation.operationGuid,
          finishedAt: DateTime.utc(2026, 8, 27, 13),
        );
      }
      summary = (await tripStore.listSnapshots(driverGuid: 'DRIVER-A')).single;
      expect(summary.locallyCompleted, isTrue);
      expect(summary.awaitingSync, isFalse);
      expect(
        await outboxStore.pendingOrderIds(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
          stopId: 20,
        ),
        isEmpty,
      );
      expect(
        await outboxStore.pendingStopIds(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
        ),
        isEmpty,
      );
    },
  );

  test('falha ao inserir outbox reverte a ocorrência atualizada', () async {
    await _seed(tripStore, _trip());
    final duplicateGuid = _guid(1);
    await outboxStore.enqueue(
      _operation(duplicateGuid, occurrenceGuid: 'PREEXISTENTE'),
    );

    await expectLater(
      _read(
        deliveryStore,
        index: 1,
        code: 'CODIGO-C',
        operationGuid: duplicateGuid,
      ),
      throwsA(isA<DatabaseException>()),
    );

    final snapshot = await _snapshot(tripStore);
    expect(snapshot.stops.first.pendingFor(200), 4);
    expect(await _outboxCount(appDatabase), 1);
  });

  test('falha ao atualizar ocorrência impede criação da outbox', () async {
    await _seed(tripStore, _trip());
    final database = await appDatabase.database;
    await database.execute('''
      CREATE TRIGGER fail_local_occurrence_update
      BEFORE UPDATE ON ${AppDatabase.localOccurrenceTable}
      BEGIN
        SELECT RAISE(ABORT, 'falha simulada');
      END
    ''');

    await expectLater(
      _read(deliveryStore, index: 1, code: 'CODIGO-C'),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _outboxCount(appDatabase), 0);
    final snapshot = await _snapshot(tripStore);
    expect(snapshot.stops.first.pendingFor(200), 4);
  });

  test(
    'operação sending existente não gera nova operação na releitura',
    () async {
      await _seed(tripStore, _trip());
      final accepted = await _read(deliveryStore, index: 1, code: 'ROLO-22');
      await outboxStore.markSending(
        accepted.operationGuid,
        attemptedAt: DateTime.utc(2026, 8, 27, 12, 1),
      );

      await expectLater(
        _read(deliveryStore, index: 2, code: 'ROLO-22'),
        throwsA(isA<LocalDeliveryRejection>()),
      );
      expect(await _outboxCount(appDatabase), 1);
      final operation = await outboxStore.find(accepted.operationGuid);
      expect(operation!.state, OutboxSyncState.sending);
      expect(operation.operationGuid, accepted.operationGuid);
    },
  );

  test('Parada com dois Pedidos conclui somente depois do segundo', () async {
    await _seed(tripStore, _twoOrdersTrip());

    final first = await _read(deliveryStore, index: 1, code: 'PEDIDO-1');
    var snapshot = await _snapshot(tripStore);
    expect(first.pendingOrder, 0);
    expect(first.pendingStop, 1);
    expect(snapshot.stops.single.orders.first.status, 'E');
    expect(snapshot.stops.single.orders.last.status, 'P');
    expect(snapshot.stops.single.status, 'P');

    final second = await _read(
      deliveryStore,
      index: 2,
      code: 'PEDIDO-2',
      orderId: 201,
    );
    snapshot = await _snapshot(tripStore);
    expect(second.pendingOrder, 0);
    expect(second.pendingStop, 0);
    expect(
      snapshot.stops.single.orders.every((order) => order.status == 'E'),
      isTrue,
    );
    expect(snapshot.stops.single.status, 'E');
  });
}

AppDatabase _database(String databasePath) {
  return AppDatabase(factory: databaseFactoryFfi, databasePath: databasePath);
}

Future<void> _seed(TripLocalStore store, TripDetail trip) {
  return store.replaceSnapshot(
    driverGuid: 'DRIVER-A',
    trip: trip,
    downloadedAt: DateTime.utc(2026, 8, 27, 12),
    lastServerSyncAt: DateTime.utc(2026, 8, 27, 12),
  );
}

Future<TripDetail> _snapshot(TripLocalStore store) async {
  return (await store.readSnapshot(
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
  ))!;
}

Future<int> _outboxCount(AppDatabase appDatabase) async {
  final database = await appDatabase.database;
  return Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM ${AppDatabase.outboxOperationTable}',
        ),
      ) ??
      0;
}

Future<LocalDeliveryAcceptance> _read(
  DeliveryLocalStore store, {
  required int index,
  required String code,
  String? operationGuid,
  int orderId = 200,
}) {
  return store.registerRead(
    operationGuid: operationGuid ?? _guid(index),
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
    stopId: 20,
    orderId: orderId,
    code: code,
    deviceDateTime: DateTime.utc(2026, 8, 27, 12, index),
    timezoneOffsetMinutes: -180,
  );
}

String _guid(int index) {
  return '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';
}

OutboxOperation _operation(String guid, {required String occurrenceGuid}) {
  return OutboxOperation(
    operationGuid: guid,
    operationType: 'delivery_read',
    payloadVersion: 1,
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
    occurrenceGuid: occurrenceGuid,
    stopId: 20,
    orderId: 200,
    code: 'CODIGO-C',
    deviceDateTime: DateTime.utc(2026, 8, 27, 12),
    timezoneOffsetMinutes: -180,
    payloadJson: '{}',
    state: OutboxSyncState.pending,
    attemptCount: 0,
    createdAt: DateTime.utc(2026, 8, 27, 12),
  );
}

TripDetail _trip() {
  return TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 527,
    description: 'VIAGEM LOCAL',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    occurrenceCount: 6,
    stops: [
      TripStop(
        id: 20,
        plannedOrder: 1,
        status: 'P',
        clientName: 'CLIENTE ATUAL',
        city: 'UBÁ',
        state: 'MG',
        address: '',
        orders: const [
          TripOrder(id: 200, status: 'P'),
          TripOrder(id: 201, status: 'P'),
        ],
        occurrences: [
          _occurrence(1, 'C-1', 200, 'CODIGO-C'),
          _occurrence(2, 'C-2', 200, 'CODIGO-C'),
          _occurrence(3, 'R-22', 200, 'ROLO-22', type: 'R', rollId: 22),
          _occurrence(4, 'ATUAL-EXTRA', 200, 'ATUAL-EXTRA'),
          _occurrence(5, 'OUTRO-PEDIDO', 201, 'OUTRO-PEDIDO'),
        ],
      ),
      TripStop(
        id: 10,
        plannedOrder: 2,
        status: 'P',
        clientName: 'OUTRO CLIENTE',
        city: 'MURIAÉ',
        state: 'MG',
        address: '',
        orders: const [TripOrder(id: 100, status: 'P')],
        occurrences: [_occurrence(6, 'OUTRA-PARADA', 100, 'OUTRA-PARADA')],
      ),
    ],
  );
}

TripDetail _otherManifest() {
  return TripDetail(
    manifestGuid: 'MANIFEST-2',
    manifestStatus: 'L',
    loadId: 900,
    description: 'OUTRA CARGA',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    occurrenceCount: 1,
    stops: [
      TripStop(
        id: 30,
        plannedOrder: 1,
        status: 'P',
        clientName: 'OUTRA CARGA',
        city: 'UBÁ',
        state: 'MG',
        address: '',
        orders: const [TripOrder(id: 300, status: 'P')],
        occurrences: [_occurrence(30, 'OUTRA-CARGA', 300, 'OUTRA-CARGA')],
      ),
    ],
  );
}

TripDetail _tenOccurrencesTrip() {
  return TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 527,
    description: 'DEZ ETIQUETAS',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    occurrenceCount: 10,
    stops: [
      TripStop(
        id: 20,
        plannedOrder: 1,
        status: 'P',
        clientName: 'CLIENTE',
        city: 'UBÁ',
        state: 'MG',
        address: '',
        orders: const [TripOrder(id: 900, status: 'P')],
        occurrences: [
          for (var index = 1; index <= 10; index++)
            _occurrence(index, 'C-$index', 900, 'C-DEZ'),
        ],
      ),
    ],
  );
}

TripDetail _twoOrdersTrip() {
  return TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 527,
    description: 'DOIS PEDIDOS',
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
        orders: const [
          TripOrder(id: 200, status: 'P'),
          TripOrder(id: 201, status: 'P'),
        ],
        occurrences: [
          _occurrence(1, 'P-1', 200, 'PEDIDO-1'),
          _occurrence(2, 'P-2', 201, 'PEDIDO-2'),
        ],
      ),
    ],
  );
}

ManifestOccurrence _occurrence(
  int id,
  String guid,
  int orderId,
  String code, {
  String type = 'C',
  int? rollId,
}) {
  return ManifestOccurrence(
    id: id,
    guid: guid,
    orderId: orderId,
    productId: 1000 + id,
    type: type,
    code: code,
    quantity: '1.0000',
    status: 'P',
    rollId: rollId,
  );
}
