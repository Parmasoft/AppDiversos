import 'dart:async';
import 'dart:io';

import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/errors/api_exception.dart';
import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:app_motorista/sync/services/outbox_retry_policy.dart';
import 'package:app_motorista/sync/services/outbox_sync_controller.dart';
import 'package:app_motorista/viagens/local/delivery_local_store.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late TripLocalStore tripStore;
  late DeliveryLocalStore deliveryStore;
  late OutboxLocalStore outboxStore;
  late SessionController sessionController;
  late _Clock clock;

  OutboxSyncController createController({
    required PersistedOperationSender send,
  }) {
    return OutboxSyncController(
      sessionController: sessionController,
      outboxLocalStore: outboxStore,
      deliveryLocalStore: deliveryStore,
      send: send,
      retryPolicy: const OutboxRetryPolicy(
        initialDelay: Duration(seconds: 10),
        maximumDelay: Duration(seconds: 40),
      ),
      now: () => clock.value,
    );
  }

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-outbox-sync-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = _database(databasePath);
    tripStore = TripLocalStore(appDatabase);
    deliveryStore = DeliveryLocalStore(appDatabase);
    outboxStore = OutboxLocalStore(appDatabase);
    await tripStore.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(),
      downloadedAt: DateTime.utc(2026, 9, 2, 10),
      lastServerSyncAt: DateTime.utc(2026, 9, 2, 10),
    );
    sessionController = SessionController(
      repository: FakeAuthGateway(),
      storage: MemorySessionStorage(_session()),
      now: () => DateTime.utc(2026, 9, 2, 10),
    );
    await sessionController.restore();
    clock = _Clock(DateTime.utc(2026, 9, 2, 10));
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'processa em ordem usando os mesmos UUIDs e payloads persistidos',
    () async {
      final first = await _read(deliveryStore, 1, clock.value);
      clock.value = clock.value.add(const Duration(minutes: 1));
      final second = await _read(deliveryStore, 2, clock.value);
      final originals = [
        (await outboxStore.find(first.operationGuid))!,
        (await outboxStore.find(second.operationGuid))!,
      ];
      final sent = <OutboxOperation>[];
      final controller = createController(
        send: (operation, _) async {
          sent.add(operation);
          return _accepted(
            occurrenceGuid: operation.occurrenceGuid!,
            replay: sent.length == 2,
          );
        },
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final report = await controller.processNow();

      expect(sent.map((item) => item.operationGuid), [
        first.operationGuid,
        second.operationGuid,
      ]);
      expect(sent.map((item) => item.payloadJson), [
        originals[0].payloadJson,
        originals[1].payloadJson,
      ]);
      expect(report.attempted, 2);
      expect(report.confirmed, 2);
      expect(notifications, 1);
      expect(
        (await outboxStore.find(first.operationGuid))!.state,
        OutboxSyncState.synced,
      );
      expect(
        (await outboxStore.find(second.operationGuid))!.state,
        OutboxSyncState.synced,
      );
      final summary = (await tripStore.listSnapshots(
        driverGuid: 'DRIVER-A',
      )).single;
      expect(summary.locallyCompleted, isTrue);
      expect(summary.awaitingSync, isFalse);
      controller.dispose();
    },
  );

  test(
    'resposta perdida agenda backoff e replay reutiliza o mesmo UUID',
    () async {
      final accepted = await _read(deliveryStore, 1, clock.value);
      final original = (await outboxStore.find(accepted.operationGuid))!;
      final sent = <OutboxOperation>[];
      final controller = createController(
        send: (operation, _) async {
          sent.add(operation);
          if (sent.length == 1) {
            throw const ApiException('conexão interrompida');
          }
          return _accepted(
            occurrenceGuid: operation.occurrenceGuid!,
            replay: true,
          );
        },
      );

      final failed = await controller.processNow();
      final retry = (await outboxStore.find(accepted.operationGuid))!;
      expect(failed.attempted, 1);
      expect(retry.state, OutboxSyncState.retry);
      expect(retry.attemptCount, 1);
      expect(retry.nextAttemptAt, isNotNull);

      final tooEarly = await controller.processNow();
      expect(tooEarly.attempted, 0);
      expect(sent, hasLength(1));

      clock.value = retry.nextAttemptAt!;
      final replayed = await controller.processNow();
      final synced = (await outboxStore.find(accepted.operationGuid))!;
      expect(replayed.confirmed, 1);
      expect(sent, hasLength(2));
      expect(
        sent.every((item) => item.operationGuid == original.operationGuid),
        isTrue,
      );
      expect(
        sent.every((item) => item.payloadJson == original.payloadJson),
        isTrue,
      );
      expect(synced.state, OutboxSyncState.synced);
      expect(synced.attemptCount, 2);
      controller.dispose();
    },
  );

  test(
    'falha temporária da cabeça não permite ultrapassagem da fila',
    () async {
      final first = await _read(deliveryStore, 1, clock.value);
      clock.value = clock.value.add(const Duration(minutes: 1));
      final second = await _read(deliveryStore, 2, clock.value);
      final sent = <String>[];
      final controller = createController(
        send: (operation, _) async {
          sent.add(operation.operationGuid);
          throw const ApiException('API continua fora', statusCode: 503);
        },
      );

      await controller.processNow();
      await controller.processNow();

      expect(sent, [first.operationGuid]);
      expect(
        (await outboxStore.find(first.operationGuid))!.state,
        OutboxSyncState.retry,
      );
      expect(
        (await outboxStore.find(second.operationGuid))!.state,
        OutboxSyncState.pending,
      );
      expect((await outboxStore.find(second.operationGuid))!.attemptCount, 0);
      controller.dispose();
    },
  );

  test('reabre banco, recupera sending e confirma sem trocar UUID', () async {
    final accepted = await _read(deliveryStore, 1, clock.value);
    await outboxStore.markSending(
      accepted.operationGuid,
      attemptedAt: clock.value,
    );
    final beforeClose = (await outboxStore.find(accepted.operationGuid))!;

    await appDatabase.close();
    appDatabase = _database(databasePath);
    tripStore = TripLocalStore(appDatabase);
    deliveryStore = DeliveryLocalStore(appDatabase);
    outboxStore = OutboxLocalStore(appDatabase);
    OutboxOperation? resent;
    final controller = createController(
      send: (operation, _) async {
        resent = operation;
        return _accepted(
          occurrenceGuid: operation.occurrenceGuid!,
          replay: true,
        );
      },
    );

    final report = await controller.processNow();
    final recovered = (await outboxStore.find(accepted.operationGuid))!;

    expect(report.confirmed, 1);
    expect(resent!.operationGuid, beforeClose.operationGuid);
    expect(resent!.payloadJson, beforeClose.payloadJson);
    expect(recovered.state, OutboxSyncState.synced);
    expect(recovered.attemptCount, 2);
    controller.dispose();
  });

  test(
    'recusa e conflito são terminais e reconciliam a mutação local',
    () async {
      final first = await _read(deliveryStore, 1, clock.value);
      clock.value = clock.value.add(const Duration(minutes: 1));
      final second = await _read(deliveryStore, 2, clock.value);
      var calls = 0;
      final controller = createController(
        send: (operation, _) async {
          calls++;
          return calls == 1 ? _rejected() : _conflict();
        },
      );

      final report = await controller.processNow();
      final snapshot = (await tripStore.readSnapshot(
        driverGuid: 'DRIVER-A',
        manifestGuid: 'MANIFEST-1',
      ))!;

      expect(report.rejected, 1);
      expect(report.conflicts, 1);
      expect(
        (await outboxStore.find(first.operationGuid))!.state,
        OutboxSyncState.rejected,
      );
      expect(
        (await outboxStore.find(second.operationGuid))!.state,
        OutboxSyncState.conflict,
      );
      expect(snapshot.stops.single.pendingFor(200), 2);
      expect(snapshot.stops.single.deliveredFor(200), 0);
      expect(snapshot.stops.single.orders.single.status, 'P');
      expect(
        await outboxStore.hasPendingForManifest(
          driverGuid: 'DRIVER-A',
          manifestGuid: 'MANIFEST-1',
        ),
        isFalse,
      );
      controller.dispose();
    },
  );

  test('duas solicitações concorrentes compartilham um único envio', () async {
    final accepted = await _read(deliveryStore, 1, clock.value);
    final response = Completer<DeliveryReadResult>();
    final sendStarted = Completer<void>();
    var calls = 0;
    final controller = createController(
      send: (operation, _) {
        calls++;
        if (!sendStarted.isCompleted) sendStarted.complete();
        return response.future;
      },
    );

    final firstRun = controller.processNow();
    final secondRun = controller.processNow();
    await sendStarted.future;
    expect(identical(firstRun, secondRun), isTrue);
    expect(calls, 1);

    response.complete(
      _accepted(occurrenceGuid: accepted.occurrenceGuid, replay: false),
    );
    await Future.wait([firstRun, secondRun]);
    expect(calls, 1);
    expect((await outboxStore.find(accepted.operationGuid))!.attemptCount, 1);
    controller.dispose();
  });

  test('nova pendência acorda o processador já iniciado', () async {
    final sendStarted = Completer<void>();
    final response = Completer<DeliveryReadResult>();
    OutboxOperation? sent;
    final controller = createController(
      send: (operation, _) {
        sent = operation;
        sendStarted.complete();
        return response.future;
      },
    );
    controller.start();
    await controller.processNow();

    final accepted = await _read(deliveryStore, 1, clock.value);
    controller.outboxChanged();
    await sendStarted.future;
    response.complete(
      _accepted(occurrenceGuid: accepted.occurrenceGuid, replay: false),
    );
    await controller.processNow();

    expect(sent!.operationGuid, accepted.operationGuid);
    expect(
      (await outboxStore.find(accepted.operationGuid))!.state,
      OutboxSyncState.synced,
    );
    controller.dispose();
  });

  test('backoff cresce exponencialmente com jitter limitado ao teto', () {
    const policy = OutboxRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maximumDelay: Duration(minutes: 5),
    );
    final delays = [
      for (var attempt = 1; attempt <= 10; attempt++)
        policy.delayFor(operationGuid: _guid(1), attempt: attempt),
    ];

    expect(delays[1], greaterThan(delays[0]));
    expect(delays[2], greaterThan(delays[1]));
    expect(delays[3], greaterThan(delays[2]));
    expect(
      delays.every((delay) => delay <= const Duration(minutes: 5)),
      isTrue,
    );
  });
}

AppDatabase _database(String databasePath) {
  return AppDatabase(factory: databaseFactoryFfi, databasePath: databasePath);
}

DriverSession _session() {
  return DriverSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    accessExpiresAt: DateTime.utc(2030),
    driver: const DriverIdentity(guid: 'DRIVER-A', name: 'Motorista'),
  );
}

Future<LocalDeliveryAcceptance> _read(
  DeliveryLocalStore store,
  int index,
  DateTime dateTime,
) {
  return store.registerRead(
    operationGuid: _guid(index),
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
    stopId: 20,
    orderId: 200,
    code: 'CODIGO-C',
    deviceDateTime: dateTime,
    timezoneOffsetMinutes: -180,
  );
}

String _guid(int index) {
  return '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';
}

DeliveryReadResult _accepted({
  required String occurrenceGuid,
  required bool replay,
}) {
  return DeliveryReadResult(
    result: 'ACEITA',
    responseCode: replay ? 'REPLAY' : 'OK',
    message: replay ? 'Operação já processada.' : 'Registrada.',
    replay: replay,
    occurrenceGuid: occurrenceGuid,
    orderId: 200,
    pendingOrder: 0,
    pendingStop: 0,
  );
}

DeliveryReadResult _rejected() {
  return const DeliveryReadResult(
    result: 'RECUSADA',
    responseCode: 'CODIGO_RECUSADO',
    message: 'Operação recusada.',
    replay: false,
  );
}

DeliveryReadResult _conflict() {
  return const DeliveryReadResult(
    result: 'CONFLITO',
    responseCode: 'OPERACAO_CONFLITANTE',
    message: 'UUID usado com conteúdo diferente.',
    replay: true,
  );
}

TripDetail _trip() {
  return const TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 999,
    description: 'VIAGEM CONTROLADA',
    driverName: 'MOTORISTA',
    originName: 'ORIGEM',
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
            productId: 1,
            type: 'C',
            code: 'CODIGO-C',
            quantity: '1',
            status: 'P',
          ),
          ManifestOccurrence(
            id: 2,
            guid: 'OC-2',
            orderId: 200,
            productId: 1,
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

class _Clock {
  _Clock(this.value);

  DateTime value;
}
