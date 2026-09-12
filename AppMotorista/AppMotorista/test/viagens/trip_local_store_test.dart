import 'dart:io';

import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;
  late TripLocalStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-trip-store-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    store = TripLocalStore(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('snapshot completo sobrevive ao fechamento e preserva C/R', () async {
    final expected = _trip(loadId: 527);
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: expected,
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
      lastServerSyncAt: DateTime.utc(2026, 8, 27, 12),
    );

    await appDatabase.close();
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    store = TripLocalStore(appDatabase);
    final restored = await store.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );

    expect(restored, isNotNull);
    expect(restored!.loadId, 527);
    expect(restored.stops.map((stop) => stop.id), [20, 10]);
    expect(restored.stops.first.orders.map((order) => order.id), [200, 201]);
    final occurrences = restored.stops.first.occurrences;
    expect(occurrences.map((item) => item.guid), ['C-1', 'C-2', 'R-22']);
    expect(occurrences[0].code, occurrences[1].code);
    expect(occurrences[0].type, 'C');
    expect(occurrences[1].type, 'C');
    expect(occurrences[2].type, 'R');
    expect(occurrences[2].rollId, 22);
  });

  test('substituição do snapshot é atômica e não duplica linhas', () async {
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(loadId: 527),
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
    );
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(loadId: 528),
      downloadedAt: DateTime.utc(2026, 8, 27, 13),
    );

    final database = await appDatabase.database;
    expect(
      (await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${AppDatabase.localTripTable}',
      )).single['total'],
      1,
    );
    expect(
      (await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${AppDatabase.localStopTable}',
      )).single['total'],
      2,
    );
    expect(
      (await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${AppDatabase.localOrderTable}',
      )).single['total'],
      3,
    );
    expect(
      (await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${AppDatabase.localOccurrenceTable}',
      )).single['total'],
      4,
    );
    final restored = await store.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );
    expect(restored!.loadId, 528);
  });

  test('falha no meio da substituição restaura o snapshot anterior', () async {
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(loadId: 527),
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
    );

    await expectLater(
      store.replaceSnapshot(
        driverGuid: 'DRIVER-A',
        trip: _trip(loadId: 999, duplicateOccurrenceGuid: true),
        downloadedAt: DateTime.utc(2026, 8, 27, 13),
      ),
      throwsA(isA<DatabaseException>()),
    );

    final restored = await store.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );
    expect(restored!.loadId, 527);
    expect(restored.occurrenceCount, 4);
  });

  test('o mesmo Manifesto fica isolado pelo driver_guid', () async {
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-A',
      trip: _trip(loadId: 527),
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
    );
    await store.replaceSnapshot(
      driverGuid: 'DRIVER-B',
      trip: _trip(loadId: 900),
      downloadedAt: DateTime.utc(2026, 8, 27, 12),
    );

    final driverA = await store.readSnapshot(
      driverGuid: 'DRIVER-A',
      manifestGuid: 'MANIFEST-1',
    );
    final driverB = await store.readSnapshot(
      driverGuid: 'DRIVER-B',
      manifestGuid: 'MANIFEST-1',
    );
    final unknown = await store.readSnapshot(
      driverGuid: 'DRIVER-C',
      manifestGuid: 'MANIFEST-1',
    );

    expect(driverA!.loadId, 527);
    expect(driverB!.loadId, 900);
    expect(unknown, isNull);
  });
}

TripDetail _trip({required int loadId, bool duplicateOccurrenceGuid = false}) {
  return TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: loadId,
    description: 'VIAGEM TESTE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    departureDate: '2026-08-27',
    departureTime: '08:30:00',
    occurrenceCount: 4,
    stops: [
      TripStop(
        id: 20,
        plannedOrder: 2,
        status: 'P',
        clientName: 'CLIENTE DOIS',
        city: 'MURIAÉ',
        state: 'MG',
        address: 'RUA DOIS, 20',
        orders: const [
          TripOrder(id: 200, status: 'P'),
          TripOrder(id: 201, status: 'P'),
        ],
        occurrences: [
          _occurrence(id: 1, guid: 'C-1', orderId: 200),
          _occurrence(
            id: 2,
            guid: duplicateOccurrenceGuid ? 'C-1' : 'C-2',
            orderId: 200,
          ),
          _occurrence(id: 3, guid: 'R-22', orderId: 201, type: 'R', rollId: 22),
        ],
      ),
      TripStop(
        id: 10,
        plannedOrder: 1,
        status: 'P',
        clientName: 'CLIENTE UM',
        city: 'UBÁ',
        state: 'MG',
        address: 'RUA UM, 10',
        orders: const [TripOrder(id: 100, status: 'P')],
        occurrences: [_occurrence(id: 4, guid: 'C-4', orderId: 100)],
      ),
    ],
  );
}

ManifestOccurrence _occurrence({
  required int id,
  required String guid,
  required int orderId,
  String type = 'C',
  int? rollId,
}) {
  return ManifestOccurrence(
    id: id,
    guid: guid,
    orderId: orderId,
    productId: 1000 + id,
    type: type,
    code: type == 'C' ? 'CODIGO-C-REPETIDO' : 'ROLO-22',
    quantity: '1.0000',
    status: 'P',
    rollId: rollId,
  );
}
