import '../../storage/app_database.dart';
import '../models/trip_detail.dart';
import '../models/trip_summary.dart';

class TripLocalStore {
  const TripLocalStore(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> replaceSnapshot({
    required String driverGuid,
    required TripDetail trip,
    required DateTime downloadedAt,
    DateTime? lastServerSyncAt,
    String syncState = 'synced',
  }) async {
    if (driverGuid.trim().isEmpty || trip.manifestGuid.trim().isEmpty) {
      throw ArgumentError('Motorista e Manifesto são obrigatórios.');
    }
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final keyWhere = 'driver_guid = ? AND manifest_guid = ?';
      final keyArguments = [driverGuid, trip.manifestGuid];
      await transaction.delete(
        AppDatabase.localTripTable,
        where: keyWhere,
        whereArgs: keyArguments,
      );
      await transaction.insert(AppDatabase.localTripTable, {
        'driver_guid': driverGuid,
        'manifest_guid': trip.manifestGuid,
        'load_id': trip.loadId,
        'manifest_status': trip.manifestStatus,
        'description': trip.description,
        'driver_name': trip.driverName,
        'origin_name': trip.originName,
        'departure_date': trip.departureDate,
        'departure_time': trip.departureTime,
        'occurrence_count': trip.occurrenceCount,
        'downloaded_at': _date(downloadedAt),
        'last_server_sync_at': _nullableDate(lastServerSyncAt),
        'sync_state': syncState,
      });

      for (var stopIndex = 0; stopIndex < trip.stops.length; stopIndex++) {
        final stop = trip.stops[stopIndex];
        await transaction.insert(AppDatabase.localStopTable, {
          'driver_guid': driverGuid,
          'manifest_guid': trip.manifestGuid,
          'stop_id': stop.id,
          'sort_index': stopIndex,
          'planned_order': stop.plannedOrder,
          'status': stop.status,
          'client_name': stop.clientName,
          'city': stop.city,
          'state': stop.state,
          'address': stop.address,
        });

        for (
          var orderIndex = 0;
          orderIndex < stop.orders.length;
          orderIndex++
        ) {
          final order = stop.orders[orderIndex];
          await transaction.insert(AppDatabase.localOrderTable, {
            'driver_guid': driverGuid,
            'manifest_guid': trip.manifestGuid,
            'stop_id': stop.id,
            'order_id': order.id,
            'sort_index': orderIndex,
            'status': order.status,
          });
        }

        for (
          var occurrenceIndex = 0;
          occurrenceIndex < stop.occurrences.length;
          occurrenceIndex++
        ) {
          final occurrence = stop.occurrences[occurrenceIndex];
          await transaction.insert(AppDatabase.localOccurrenceTable, {
            'driver_guid': driverGuid,
            'manifest_guid': trip.manifestGuid,
            'occurrence_guid': occurrence.guid,
            'occurrence_id': occurrence.id,
            'stop_id': stop.id,
            'order_id': occurrence.orderId,
            'sort_index': occurrenceIndex,
            'product_id': occurrence.productId,
            'type': occurrence.type,
            'code': occurrence.code,
            'roll_id': occurrence.rollId,
            'quantity': occurrence.quantity,
            'status': occurrence.status,
            'sync_state': syncState,
          });
        }
      }
    });
  }

  Future<TripDetail?> readSnapshot({
    required String driverGuid,
    required String manifestGuid,
  }) async {
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      final trips = await transaction.query(
        AppDatabase.localTripTable,
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
        limit: 1,
      );
      if (trips.isEmpty) return null;
      final trip = trips.single;
      final stopRows = await transaction.query(
        AppDatabase.localStopTable,
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
        orderBy: 'sort_index',
      );
      final orderRows = await transaction.query(
        AppDatabase.localOrderTable,
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
        orderBy: 'stop_id, sort_index',
      );
      final occurrenceRows = await transaction.query(
        AppDatabase.localOccurrenceTable,
        where: 'driver_guid = ? AND manifest_guid = ?',
        whereArgs: [driverGuid, manifestGuid],
        orderBy: 'stop_id, sort_index',
      );

      return TripDetail(
        manifestGuid: _string(trip, 'manifest_guid'),
        manifestStatus: _string(trip, 'manifest_status'),
        loadId: _integer(trip, 'load_id'),
        description: _string(trip, 'description'),
        driverName: _string(trip, 'driver_name'),
        originName: _string(trip, 'origin_name'),
        departureDate: _nullableString(trip, 'departure_date'),
        departureTime: _nullableString(trip, 'departure_time'),
        occurrenceCount: _integer(trip, 'occurrence_count'),
        stops: [
          for (final stop in stopRows)
            TripStop(
              id: _integer(stop, 'stop_id'),
              plannedOrder: _integer(stop, 'planned_order'),
              status: _string(stop, 'status'),
              clientName: _string(stop, 'client_name'),
              city: _string(stop, 'city'),
              state: _string(stop, 'state'),
              address: _string(stop, 'address'),
              orders: [
                for (final order in orderRows)
                  if (_integer(order, 'stop_id') == _integer(stop, 'stop_id'))
                    TripOrder(
                      id: _integer(order, 'order_id'),
                      status: _string(order, 'status'),
                    ),
              ],
              occurrences: [
                for (final occurrence in occurrenceRows)
                  if (_integer(occurrence, 'stop_id') ==
                      _integer(stop, 'stop_id'))
                    ManifestOccurrence(
                      id: _integer(occurrence, 'occurrence_id'),
                      guid: _string(occurrence, 'occurrence_guid'),
                      orderId: _integer(occurrence, 'order_id'),
                      productId: _integer(occurrence, 'product_id'),
                      type: _string(occurrence, 'type'),
                      code: _string(occurrence, 'code'),
                      rollId: _nullableInteger(occurrence, 'roll_id'),
                      quantity: _string(occurrence, 'quantity'),
                      status: _string(occurrence, 'status'),
                    ),
              ],
            ),
        ],
      );
    });
  }

  Future<List<TripSummary>> listSnapshots({required String driverGuid}) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      SELECT
        trip.manifest_guid,
        trip.load_id,
        trip.description,
        trip.departure_date,
        trip.departure_time,
        trip.occurrence_count,
        CASE
          WHEN trip.occurrence_count > 0 AND NOT EXISTS (
            SELECT 1
            FROM ${AppDatabase.localOccurrenceTable} occurrence
            WHERE occurrence.driver_guid = trip.driver_guid
              AND occurrence.manifest_guid = trip.manifest_guid
              AND occurrence.status <> 'E'
          ) THEN 1
          ELSE 0
        END AS locally_completed,
        CASE
          WHEN EXISTS (
            SELECT 1
            FROM ${AppDatabase.outboxOperationTable} operation
            WHERE operation.driver_guid = trip.driver_guid
              AND operation.manifest_guid = trip.manifest_guid
              AND operation.state IN ('pending','sending','retry')
          ) THEN 1
          ELSE 0
        END AS awaiting_sync,
        (
          SELECT COUNT(*)
          FROM ${AppDatabase.localStopTable} stop
          WHERE stop.driver_guid = trip.driver_guid
            AND stop.manifest_guid = trip.manifest_guid
        ) AS stop_count
      FROM ${AppDatabase.localTripTable} trip
      WHERE trip.driver_guid = ?
      ORDER BY trip.downloaded_at DESC, trip.manifest_guid
      ''',
      [driverGuid],
    );
    return List.unmodifiable(
      rows.map(
        (row) => TripSummary(
          manifestGuid: _string(row, 'manifest_guid'),
          loadId: _integer(row, 'load_id'),
          description: _string(row, 'description'),
          stopCount: _integer(row, 'stop_count'),
          occurrenceCount: _integer(row, 'occurrence_count'),
          locallyCompleted: _integer(row, 'locally_completed') == 1,
          awaitingSync: _integer(row, 'awaiting_sync') == 1,
          departureDate: _nullableString(row, 'departure_date'),
          departureTime: _nullableString(row, 'departure_time'),
        ),
      ),
    );
  }
}

String _date(DateTime value) => value.toUtc().toIso8601String();

String? _nullableDate(DateTime? value) => value == null ? null : _date(value);

String _string(Map<String, Object?> row, String field) =>
    row[field]?.toString() ?? '';

String? _nullableString(Map<String, Object?> row, String field) =>
    row[field]?.toString();

int _integer(Map<String, Object?> row, String field) =>
    (row[field] as num).toInt();

int? _nullableInteger(Map<String, Object?> row, String field) {
  final value = row[field];
  return value == null ? null : (value as num).toInt();
}
