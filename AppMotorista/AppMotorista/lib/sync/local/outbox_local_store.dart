import 'package:sqflite/sqflite.dart';

import '../../storage/app_database.dart';
import '../models/outbox_operation.dart';

class OutboxLocalStore {
  const OutboxLocalStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> enqueue(OutboxOperation operation) async {
    final database = await _appDatabase.database;
    await database.insert(
      AppDatabase.outboxOperationTable,
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<OutboxOperation?> find(String operationGuid) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      AppDatabase.outboxOperationTable,
      where: 'operation_guid = ?',
      whereArgs: [operationGuid],
      limit: 1,
    );
    return rows.isEmpty ? null : OutboxOperation.fromMap(rows.single);
  }

  /// Reads the driver's complete local outbox without changing its state.
  /// Active and problematic operations are returned before synced ones.
  Future<List<OutboxOperation>> listForDiagnostic({
    required String driverGuid,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      AppDatabase.outboxOperationTable,
      where: 'driver_guid = ?',
      whereArgs: [driverGuid],
      orderBy: '''
        CASE state
          WHEN 'pending' THEN 0
          WHEN 'sending' THEN 1
          WHEN 'retry' THEN 2
          WHEN 'rejected' THEN 3
          WHEN 'conflict' THEN 4
          WHEN 'synced' THEN 5
          ELSE 6
        END,
        created_at DESC,
        operation_guid
      ''',
    );
    return List.unmodifiable(rows.map(OutboxOperation.fromMap));
  }

  Future<List<OutboxOperation>> listSyncedDeliveryReads({
    required String driverGuid,
    required String manifestGuid,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      AppDatabase.outboxOperationTable,
      where:
          'driver_guid = ? AND manifest_guid = ? '
          'AND operation_type = ? AND state = ?',
      whereArgs: [
        driverGuid,
        manifestGuid,
        'delivery_read',
        OutboxSyncState.synced.name,
      ],
      orderBy: 'created_at, operation_guid',
    );
    return List.unmodifiable(rows.map(OutboxOperation.fromMap));
  }

  Future<List<OutboxOperation>> listReady({String? driverGuid}) async {
    final database = await _appDatabase.database;
    final driverFilter = driverGuid == null ? '' : ' AND driver_guid = ?';
    final rows = await database.query(
      AppDatabase.outboxOperationTable,
      where: "state IN ('pending','retry')$driverFilter",
      whereArgs: driverGuid == null ? null : [driverGuid],
      orderBy: 'created_at, operation_guid',
    );
    return List.unmodifiable(rows.map(OutboxOperation.fromMap));
  }

  Future<int> pendingCount() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      "SELECT COUNT(*) AS total FROM ${AppDatabase.outboxOperationTable} "
      "WHERE state IN ('pending','sending','retry')",
    );
    return (rows.single['total'] as num).toInt();
  }

  Future<bool> hasPendingForDriver(String driverGuid) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      "SELECT 1 FROM ${AppDatabase.outboxOperationTable} "
      "WHERE driver_guid = ? AND state IN ('pending','sending','retry') LIMIT 1",
      [driverGuid],
    );
    return rows.isNotEmpty;
  }

  Future<int> makeRetriesReady(String driverGuid) async {
    final database = await _appDatabase.database;
    return database.update(
      AppDatabase.outboxOperationTable,
      {'state': OutboxSyncState.pending.name, 'next_attempt_at': null},
      where: 'driver_guid = ? AND state = ?',
      whereArgs: [driverGuid, OutboxSyncState.retry.name],
    );
  }

  Future<OutboxOperation?> nextInOrder({required String driverGuid}) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      AppDatabase.outboxOperationTable,
      where: "driver_guid = ? AND state IN ('pending','retry')",
      whereArgs: [driverGuid],
      orderBy: 'created_at, operation_guid',
      limit: 1,
    );
    return rows.isEmpty ? null : OutboxOperation.fromMap(rows.single);
  }

  Future<bool> hasPendingForManifest({
    required String driverGuid,
    required String manifestGuid,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
        SELECT 1
        FROM ${AppDatabase.outboxOperationTable}
        WHERE driver_guid = ? AND manifest_guid = ?
          AND state IN ('pending','sending','retry')
        LIMIT 1
      ''',
      [driverGuid, manifestGuid],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> pendingManifestGuids(String driverGuid) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
        SELECT DISTINCT manifest_guid
        FROM ${AppDatabase.outboxOperationTable}
        WHERE driver_guid = ? AND state IN ('pending','sending','retry')
      ''',
      [driverGuid],
    );
    return Set.unmodifiable(
      rows.map((row) => row['manifest_guid']?.toString() ?? ''),
    );
  }

  Future<Set<int>> pendingOrderIds({
    required String driverGuid,
    required String manifestGuid,
    required int stopId,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
        SELECT DISTINCT order_id
        FROM ${AppDatabase.outboxOperationTable}
        WHERE driver_guid = ? AND manifest_guid = ? AND stop_id = ?
          AND state IN ('pending','sending','retry')
      ''',
      [driverGuid, manifestGuid, stopId],
    );
    return Set.unmodifiable(
      rows.map((row) => (row['order_id'] as num).toInt()),
    );
  }

  Future<Set<int>> pendingStopIds({
    required String driverGuid,
    required String manifestGuid,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
        SELECT DISTINCT stop_id
        FROM ${AppDatabase.outboxOperationTable}
        WHERE driver_guid = ? AND manifest_guid = ?
          AND state IN ('pending','sending','retry')
      ''',
      [driverGuid, manifestGuid],
    );
    return Set.unmodifiable(rows.map((row) => (row['stop_id'] as num).toInt()));
  }

  Future<bool> markSending(
    String operationGuid, {
    required DateTime attemptedAt,
  }) async {
    final database = await _appDatabase.database;
    final changed = await database.rawUpdate(
      '''
        UPDATE ${AppDatabase.outboxOperationTable}
        SET state = 'sending',
            attempt_count = attempt_count + 1,
            last_attempt_at = ?,
            next_attempt_at = NULL,
            last_error = NULL
        WHERE operation_guid = ? AND state IN ('pending','retry')
      ''',
      [_date(attemptedAt), operationGuid],
    );
    return changed == 1;
  }

  Future<bool> scheduleRetry(
    String operationGuid, {
    required DateTime nextAttemptAt,
    required String error,
  }) async {
    final database = await _appDatabase.database;
    final changed = await database.update(
      AppDatabase.outboxOperationTable,
      {
        'state': OutboxSyncState.retry.name,
        'next_attempt_at': _date(nextAttemptAt),
        'last_error': error,
      },
      where: 'operation_guid = ? AND state = ?',
      whereArgs: [operationGuid, OutboxSyncState.sending.name],
    );
    return changed == 1;
  }

  Future<bool> returnToPending(
    String operationGuid, {
    required String error,
  }) async {
    final database = await _appDatabase.database;
    final changed = await database.update(
      AppDatabase.outboxOperationTable,
      {
        'state': OutboxSyncState.pending.name,
        'next_attempt_at': null,
        'last_error': error,
      },
      where: 'operation_guid = ? AND state = ?',
      whereArgs: [operationGuid, OutboxSyncState.sending.name],
    );
    return changed == 1;
  }

  Future<bool> finish(
    String operationGuid, {
    required OutboxSyncState state,
    required DateTime finishedAt,
    String? responseCode,
    String? responseJson,
    String? error,
  }) async {
    if (state != OutboxSyncState.synced &&
        state != OutboxSyncState.rejected &&
        state != OutboxSyncState.conflict) {
      throw ArgumentError.value(state, 'state', 'Estado não terminal.');
    }
    final database = await _appDatabase.database;
    final changed = await database.update(
      AppDatabase.outboxOperationTable,
      {
        'state': state.name,
        'synced_at': state == OutboxSyncState.synced ? _date(finishedAt) : null,
        'next_attempt_at': null,
        'response_code': responseCode,
        'response_json': responseJson,
        'last_error': error,
      },
      where: 'operation_guid = ? AND state = ?',
      whereArgs: [operationGuid, OutboxSyncState.sending.name],
    );
    return changed == 1;
  }

  Future<int> recoverInterruptedSending({String? driverGuid}) async {
    final database = await _appDatabase.database;
    final driverFilter = driverGuid == null ? '' : ' AND driver_guid = ?';
    return database.rawUpdate('''
        UPDATE ${AppDatabase.outboxOperationTable}
        SET state = 'pending', next_attempt_at = NULL
        WHERE state = 'sending'$driverFilter
      ''', driverGuid == null ? null : [driverGuid]);
  }
}

String _date(DateTime value) => value.toUtc().toIso8601String();
