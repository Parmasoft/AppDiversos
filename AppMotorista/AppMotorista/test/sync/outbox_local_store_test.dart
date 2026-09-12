import 'dart:io';

import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/models/outbox_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late OutboxLocalStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-outbox-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    store = OutboxLocalStore(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('outbox preserva UUID e payload depois de fechar e reabrir', () async {
    final operation = _operation('00000000-0000-4000-8000-000000000001');
    await store.enqueue(operation);

    await appDatabase.close();
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    store = OutboxLocalStore(appDatabase);
    final restored = await store.find(operation.operationGuid);

    expect(restored, isNotNull);
    expect(restored!.operationGuid, operation.operationGuid);
    expect(restored.payloadJson, operation.payloadJson);
    expect(restored.state, OutboxSyncState.pending);
    expect(restored.deviceDateTime, DateTime.utc(2026, 8, 27, 12));
  });

  test('UUID é único e uma segunda inserção não duplica operação', () async {
    final operation = _operation('00000000-0000-4000-8000-000000000002');
    await store.enqueue(operation);

    await expectLater(
      store.enqueue(operation),
      throwsA(isA<DatabaseException>()),
    );
    final database = await appDatabase.database;
    expect(
      (await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${AppDatabase.outboxOperationTable}',
      )).single['total'],
      1,
    );
  });

  test('sending interrompido volta a pending sem trocar UUID', () async {
    final operation = _operation('00000000-0000-4000-8000-000000000003');
    await store.enqueue(operation);
    expect(
      await store.markSending(
        operation.operationGuid,
        attemptedAt: DateTime.utc(2026, 8, 27, 12, 1),
      ),
      isTrue,
    );

    await appDatabase.close();
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    store = OutboxLocalStore(appDatabase);
    expect(await store.recoverInterruptedSending(), 1);
    final restored = await store.find(operation.operationGuid);

    expect(restored!.operationGuid, operation.operationGuid);
    expect(restored.state, OutboxSyncState.pending);
    expect(restored.attemptCount, 1);
    expect(restored.lastAttemptAt, DateTime.utc(2026, 8, 27, 12, 1));
  });

  test('retry e estados terminais ficam persistidos explicitamente', () async {
    final retry = _operation('00000000-0000-4000-8000-000000000004');
    await store.enqueue(retry);
    await store.markSending(
      retry.operationGuid,
      attemptedAt: DateTime.utc(2026, 8, 27, 12, 1),
    );
    await store.scheduleRetry(
      retry.operationGuid,
      nextAttemptAt: DateTime.utc(2026, 8, 27, 12, 5),
      error: 'Sem comunicação.',
    );

    for (final entry in [
      (
        guid: '00000000-0000-4000-8000-000000000005',
        state: OutboxSyncState.synced,
      ),
      (
        guid: '00000000-0000-4000-8000-000000000006',
        state: OutboxSyncState.rejected,
      ),
      (
        guid: '00000000-0000-4000-8000-000000000007',
        state: OutboxSyncState.conflict,
      ),
    ]) {
      await store.enqueue(_operation(entry.guid));
      await store.markSending(
        entry.guid,
        attemptedAt: DateTime.utc(2026, 8, 27, 12, 2),
      );
      await store.finish(
        entry.guid,
        state: entry.state,
        finishedAt: DateTime.utc(2026, 8, 27, 12, 3),
        responseCode: entry.state.name.toUpperCase(),
      );
    }

    expect(
      (await store.find(retry.operationGuid))!.state,
      OutboxSyncState.retry,
    );
    expect((await store.listReady()).map((item) => item.operationGuid), [
      retry.operationGuid,
    ]);
    expect(
      (await store.find('00000000-0000-4000-8000-000000000005'))!.state,
      OutboxSyncState.synced,
    );
    expect(
      (await store.find('00000000-0000-4000-8000-000000000006'))!.state,
      OutboxSyncState.rejected,
    );
    expect(
      (await store.find('00000000-0000-4000-8000-000000000007'))!.state,
      OutboxSyncState.conflict,
    );
  });
}

OutboxOperation _operation(String guid) {
  return OutboxOperation(
    operationGuid: guid,
    operationType: 'delivery_read',
    payloadVersion: 1,
    driverGuid: 'DRIVER-A',
    manifestGuid: 'MANIFEST-1',
    stopId: 20,
    orderId: 200,
    code: 'CODIGO-C',
    deviceDateTime: DateTime.utc(2026, 8, 27, 12),
    timezoneOffsetMinutes: -180,
    payloadJson:
        '{"codigo":"CODIGO-C","manifesto_guid":"MANIFEST-1",'
        '"operacao_guid":"$guid"}',
    state: OutboxSyncState.pending,
    attemptCount: 0,
    createdAt: DateTime.utc(2026, 8, 27, 12),
  );
}
