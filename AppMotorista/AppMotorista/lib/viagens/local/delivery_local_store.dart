import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../storage/app_database.dart';
import '../../sync/models/outbox_operation.dart';

class LocalDeliveryRejection implements Exception {
  const LocalDeliveryRejection({
    required this.responseCode,
    required this.message,
  });

  final String responseCode;
  final String message;

  @override
  String toString() => message;
}

class LocalDeliveryAcceptance {
  const LocalDeliveryAcceptance({
    required this.operationGuid,
    required this.occurrenceGuid,
    required this.type,
    required this.orderId,
    required this.pendingOrder,
    required this.pendingStop,
  });

  final String operationGuid;
  final String occurrenceGuid;
  final String type;
  final int orderId;
  final int pendingOrder;
  final int pendingStop;
}

class DeliveryLocalStore {
  const DeliveryLocalStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<LocalDeliveryAcceptance> registerRead({
    required String operationGuid,
    required String driverGuid,
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
    required DateTime deviceDateTime,
    required int timezoneOffsetMinutes,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      final trip = await transaction.query(
        AppDatabase.localTripTable,
        columns: const ['manifest_guid'],
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
        limit: 1,
      );
      if (trip.isEmpty) {
        throw const LocalDeliveryRejection(
          responseCode: 'VIAGEM_NAO_BAIXADA',
          message: 'Esta viagem precisa ser baixada antes da leitura offline.',
        );
      }

      final candidates = await transaction.query(
        AppDatabase.localOccurrenceTable,
        where:
            'driver_guid = ? AND manifest_guid = ? AND stop_id = ? '
            'AND order_id = ? AND UPPER(code) = ?',
        whereArgs: [driverGuid, manifestGuid, stopId, orderId, normalizedCode],
        orderBy: 'sort_index, occurrence_id',
      );
      if (candidates.isEmpty) {
        throw await _scopeRejection(
          transaction,
          driverGuid: driverGuid,
          manifestGuid: manifestGuid,
          stopId: stopId,
          code: normalizedCode,
        );
      }

      Map<String, Object?>? selected;
      for (final candidate in candidates) {
        if (_string(candidate, 'status') == 'P') {
          selected = candidate;
          break;
        }
      }
      if (selected == null) {
        final hasRoll = candidates.any(
          (candidate) => _string(candidate, 'type') == 'R',
        );
        throw LocalDeliveryRejection(
          responseCode: hasRoll
              ? 'ROLO_JA_RECEPCIONADO'
              : 'MULTIPLICIDADE_ESGOTADA',
          message: hasRoll
              ? 'Este rolo já foi recepcionado.'
              : 'Todas as ocorrências desta etiqueta já foram '
                    'recepcionadas no Pedido.',
        );
      }

      final occurrenceGuid = _string(selected, 'occurrence_guid');
      final changed = await transaction.update(
        AppDatabase.localOccurrenceTable,
        {'status': 'E', 'sync_state': OutboxSyncState.pending.name},
        where:
            'driver_guid = ? AND manifest_guid = ? '
            'AND occurrence_guid = ? AND status = ?',
        whereArgs: [driverGuid, manifestGuid, occurrenceGuid, 'P'],
      );
      if (changed != 1) {
        throw StateError('A ocorrência pendente não pôde ser atualizada.');
      }

      final payloadJson = jsonEncode(<String, Object>{
        'operacao_guid': operationGuid,
        'codigo': normalizedCode,
        'data_hora_aparelho': deviceDateTime.toIso8601String(),
        'fuso_minutos': timezoneOffsetMinutes,
      });
      final operation = OutboxOperation(
        operationGuid: operationGuid,
        operationType: 'delivery_read',
        payloadVersion: 1,
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
        occurrenceGuid: occurrenceGuid,
        stopId: stopId,
        orderId: orderId,
        code: normalizedCode,
        deviceDateTime: deviceDateTime,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        payloadJson: payloadJson,
        state: OutboxSyncState.pending,
        attemptCount: 0,
        createdAt: deviceDateTime,
      );
      await transaction.insert(
        AppDatabase.outboxOperationTable,
        operation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final progress = await _deriveProgress(
        transaction,
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
        stopId: stopId,
        orderId: orderId,
      );
      await transaction.update(
        AppDatabase.localTripTable,
        {'sync_state': OutboxSyncState.pending.name},
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
      );

      return LocalDeliveryAcceptance(
        operationGuid: operationGuid,
        occurrenceGuid: occurrenceGuid,
        type: _string(selected, 'type'),
        orderId: orderId,
        pendingOrder: progress.pendingOrder,
        pendingStop: progress.pendingStop,
      );
    });
  }

  Future<void> finishAccepted({
    required String operationGuid,
    required DateTime finishedAt,
    String? serverOccurrenceGuid,
    String? responseCode,
    String? responseJson,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final operation = await _operation(transaction, operationGuid);
      if (operation == null) return;
      final selectedGuid = _string(operation, 'occurrence_guid');
      final acceptedGuid = serverOccurrenceGuid?.trim().isNotEmpty == true
          ? serverOccurrenceGuid!.trim()
          : selectedGuid;

      if (acceptedGuid != selectedGuid) {
        await transaction.update(
          AppDatabase.localOccurrenceTable,
          {'status': 'P', 'sync_state': OutboxSyncState.synced.name},
          where:
              'driver_guid = ? AND manifest_guid = ? '
              'AND occurrence_guid = ?',
          whereArgs: [
            _string(operation, 'driver_guid'),
            _string(operation, 'manifest_guid'),
            selectedGuid,
          ],
        );
        final changed = await transaction.update(
          AppDatabase.localOccurrenceTable,
          {'status': 'E', 'sync_state': OutboxSyncState.synced.name},
          where:
              'driver_guid = ? AND manifest_guid = ? AND stop_id = ? '
              'AND order_id = ? AND occurrence_guid = ?',
          whereArgs: [
            _string(operation, 'driver_guid'),
            _string(operation, 'manifest_guid'),
            _integer(operation, 'stop_id'),
            _integer(operation, 'order_id'),
            acceptedGuid,
          ],
        );
        if (changed != 1) {
          throw StateError('A ocorrência confirmada pelo servidor não existe.');
        }
      } else {
        await transaction.update(
          AppDatabase.localOccurrenceTable,
          {'sync_state': OutboxSyncState.synced.name},
          where:
              'driver_guid = ? AND manifest_guid = ? '
              'AND occurrence_guid = ?',
          whereArgs: [
            _string(operation, 'driver_guid'),
            _string(operation, 'manifest_guid'),
            selectedGuid,
          ],
        );
      }

      await transaction.update(
        AppDatabase.outboxOperationTable,
        {
          'state': OutboxSyncState.synced.name,
          'synced_at': _date(finishedAt),
          'next_attempt_at': null,
          'response_code': responseCode,
          'response_json': responseJson,
          'last_error': null,
        },
        where: 'operation_guid = ?',
        whereArgs: [operationGuid],
      );
      await _deriveProgress(
        transaction,
        driverGuid: _string(operation, 'driver_guid'),
        manifestGuid: _string(operation, 'manifest_guid'),
        stopId: _integer(operation, 'stop_id'),
        orderId: _integer(operation, 'order_id'),
      );
      await _refreshTripSyncState(transaction, operation);
    });
  }

  Future<void> finishRejected({
    required String operationGuid,
    required OutboxSyncState state,
    required String? responseCode,
    required String? responseJson,
    required String? error,
  }) async {
    if (state != OutboxSyncState.rejected &&
        state != OutboxSyncState.conflict) {
      throw ArgumentError.value(state, 'state', 'Estado não terminal.');
    }
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final operation = await _operation(transaction, operationGuid);
      if (operation == null) return;
      await transaction.update(
        AppDatabase.localOccurrenceTable,
        {'status': 'P', 'sync_state': OutboxSyncState.synced.name},
        where:
            'driver_guid = ? AND manifest_guid = ? '
            'AND occurrence_guid = ?',
        whereArgs: [
          _string(operation, 'driver_guid'),
          _string(operation, 'manifest_guid'),
          _string(operation, 'occurrence_guid'),
        ],
      );
      await transaction.update(
        AppDatabase.outboxOperationTable,
        {
          'state': state.name,
          'next_attempt_at': null,
          'response_code': responseCode,
          'response_json': responseJson,
          'last_error': error,
        },
        where: 'operation_guid = ?',
        whereArgs: [operationGuid],
      );
      await _deriveProgress(
        transaction,
        driverGuid: _string(operation, 'driver_guid'),
        manifestGuid: _string(operation, 'manifest_guid'),
        stopId: _integer(operation, 'stop_id'),
        orderId: _integer(operation, 'order_id'),
      );
      await _refreshTripSyncState(transaction, operation);
    });
  }

  Future<LocalDeliveryRejection> _scopeRejection(
    Transaction transaction, {
    required String driverGuid,
    required String manifestGuid,
    required int stopId,
    required String code,
  }) async {
    final sameStop = await transaction.query(
      AppDatabase.localOccurrenceTable,
      columns: const ['order_id'],
      where:
          'driver_guid = ? AND manifest_guid = ? AND stop_id = ? '
          'AND UPPER(code) = ?',
      whereArgs: [driverGuid, manifestGuid, stopId, code],
      limit: 1,
    );
    if (sameStop.isNotEmpty) {
      return const LocalDeliveryRejection(
        responseCode: 'OUTRO_PEDIDO',
        message: 'Etiqueta pertence a outro Pedido desta Parada.',
      );
    }
    final sameManifest = await transaction.query(
      AppDatabase.localOccurrenceTable,
      columns: const ['stop_id'],
      where: 'driver_guid = ? AND manifest_guid = ? AND UPPER(code) = ?',
      whereArgs: [driverGuid, manifestGuid, code],
      limit: 1,
    );
    if (sameManifest.isNotEmpty) {
      return const LocalDeliveryRejection(
        responseCode: 'OUTRA_PARADA',
        message: 'Etiqueta pertence a outra Parada desta viagem.',
      );
    }
    final otherManifest = await transaction.query(
      AppDatabase.localOccurrenceTable,
      columns: const ['manifest_guid'],
      where: 'driver_guid = ? AND manifest_guid <> ? AND UPPER(code) = ?',
      whereArgs: [driverGuid, manifestGuid, code],
      limit: 1,
    );
    if (otherManifest.isNotEmpty) {
      return const LocalDeliveryRejection(
        responseCode: 'OUTRA_CARGA',
        message: 'Etiqueta pertence a outra Carga salva neste aparelho.',
      );
    }
    return const LocalDeliveryRejection(
      responseCode: 'CODIGO_NAO_DISPONIVEL',
      message:
          'Etiqueta não pertence ao Pedido ou não está disponível nos dados '
          'salvos.',
    );
  }

  Future<_LocalProgress> _deriveProgress(
    Transaction transaction, {
    required String driverGuid,
    required String manifestGuid,
    required int stopId,
    required int orderId,
  }) async {
    final pendingOrder = await _countPending(
      transaction,
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
      stopId: stopId,
      orderId: orderId,
    );
    await transaction.update(
      AppDatabase.localOrderTable,
      {'status': pendingOrder == 0 ? 'E' : 'P'},
      where:
          'driver_guid = ? AND manifest_guid = ? AND stop_id = ? '
          'AND order_id = ?',
      whereArgs: [driverGuid, manifestGuid, stopId, orderId],
    );
    final pendingStop = await _countPending(
      transaction,
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
      stopId: stopId,
    );
    await transaction.update(
      AppDatabase.localStopTable,
      {'status': pendingStop == 0 ? 'E' : 'P'},
      where: 'driver_guid = ? AND manifest_guid = ? AND stop_id = ?',
      whereArgs: [driverGuid, manifestGuid, stopId],
    );
    return _LocalProgress(pendingOrder: pendingOrder, pendingStop: pendingStop);
  }

  Future<int> _countPending(
    Transaction transaction, {
    required String driverGuid,
    required String manifestGuid,
    required int stopId,
    int? orderId,
  }) async {
    final orderFilter = orderId == null ? '' : ' AND order_id = ?';
    final rows = await transaction.rawQuery(
      '''
        SELECT COUNT(*) AS total
        FROM ${AppDatabase.localOccurrenceTable}
        WHERE driver_guid = ? AND manifest_guid = ? AND stop_id = ?
          AND status = 'P'$orderFilter
      ''',
      [driverGuid, manifestGuid, stopId, ?orderId],
    );
    return (rows.single['total'] as num).toInt();
  }

  Future<Map<String, Object?>?> _operation(
    Transaction transaction,
    String operationGuid,
  ) async {
    final rows = await transaction.query(
      AppDatabase.outboxOperationTable,
      where: 'operation_guid = ?',
      whereArgs: [operationGuid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> _refreshTripSyncState(
    Transaction transaction,
    Map<String, Object?> operation,
  ) async {
    final driverGuid = _string(operation, 'driver_guid');
    final manifestGuid = _string(operation, 'manifest_guid');
    final pending = await transaction.rawQuery(
      '''
        SELECT 1 FROM ${AppDatabase.outboxOperationTable}
        WHERE driver_guid = ? AND manifest_guid = ?
          AND state IN ('pending','sending','retry')
        LIMIT 1
      ''',
      [driverGuid, manifestGuid],
    );
    await transaction.update(
      AppDatabase.localTripTable,
      {
        'sync_state': pending.isEmpty
            ? OutboxSyncState.synced.name
            : OutboxSyncState.pending.name,
      },
      where: 'driver_guid = ? AND manifest_guid = ?',
      whereArgs: [driverGuid, manifestGuid],
    );
  }
}

class _LocalProgress {
  const _LocalProgress({required this.pendingOrder, required this.pendingStop});

  final int pendingOrder;
  final int pendingStop;
}

String _date(DateTime value) => value.toUtc().toIso8601String();

String _string(Map<String, Object?> row, String field) =>
    row[field]?.toString() ?? '';

int _integer(Map<String, Object?> row, String field) =>
    (row[field] as num).toInt();
