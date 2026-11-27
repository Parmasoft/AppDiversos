import 'dart:io';

import 'package:app_motorista/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;
  late AppDatabase appDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'app-motorista-database-',
    );
    databasePath = path.join(temporaryDirectory.path, 'offline.db');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('schema SQLite v2 é criado e reabre com chaves estrangeiras', () async {
    var database = await appDatabase.database;

    expect(await database.getVersion(), AppDatabase.schemaVersion);
    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    final tables = tableRows.map((row) => row['name']).toSet();
    expect(
      tables,
      containsAll({
        AppDatabase.localTripTable,
        AppDatabase.localStopTable,
        AppDatabase.localOrderTable,
        AppDatabase.localOccurrenceTable,
        AppDatabase.outboxOperationTable,
      }),
    );
    expect(
      (await database.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
      1,
    );

    await appDatabase.close();
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    database = await appDatabase.database;

    expect(await database.getVersion(), AppDatabase.schemaVersion);
    expect(
      (await database.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
      1,
    );
    final outboxColumns = await database.rawQuery(
      'PRAGMA table_info(${AppDatabase.outboxOperationTable})',
    );
    expect(
      outboxColumns.map((column) => column['name']),
      contains('occurrence_guid'),
    );
  });

  test('migração v1 para v2 preserva outbox e adiciona occurrence_guid', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE ${AppDatabase.outboxOperationTable} (
              operation_guid TEXT PRIMARY KEY NOT NULL,
              operation_type TEXT NOT NULL,
              payload_version INTEGER NOT NULL,
              driver_guid TEXT NOT NULL,
              manifest_guid TEXT NOT NULL,
              stop_id INTEGER NOT NULL,
              order_id INTEGER NOT NULL,
              code TEXT NOT NULL,
              device_datetime TEXT NOT NULL,
              timezone_offset_minutes INTEGER NOT NULL,
              payload_json TEXT NOT NULL,
              state TEXT NOT NULL,
              attempt_count INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              last_attempt_at TEXT,
              next_attempt_at TEXT,
              synced_at TEXT,
              response_code TEXT,
              response_json TEXT,
              last_error TEXT
            )
          ''');
          await database.insert(AppDatabase.outboxOperationTable, {
            'operation_guid': 'OP-LEGADA',
            'operation_type': 'delivery_read',
            'payload_version': 1,
            'driver_guid': 'DRIVER-A',
            'manifest_guid': 'MANIFEST-1',
            'stop_id': 20,
            'order_id': 200,
            'code': 'CODIGO',
            'device_datetime': '2026-08-27T12:00:00.000Z',
            'timezone_offset_minutes': -180,
            'payload_json': '{}',
            'state': 'pending',
            'attempt_count': 0,
            'created_at': '2026-08-27T12:00:00.000Z',
          });
        },
      ),
    );
    await legacy.close();

    final database = await appDatabase.database;
    expect(await database.getVersion(), AppDatabase.schemaVersion);
    final columns = await database.rawQuery(
      'PRAGMA table_info(${AppDatabase.outboxOperationTable})',
    );
    expect(columns.map((column) => column['name']), contains('occurrence_guid'));
    final operations = await database.query(AppDatabase.outboxOperationTable);
    expect(operations, hasLength(1));
    expect(operations.single['operation_guid'], 'OP-LEGADA');
    expect(operations.single['occurrence_guid'], isNull);
    expect(
      await database.query(AppDatabase.tripDownloadTable),
      isEmpty,
    );
  });
}
