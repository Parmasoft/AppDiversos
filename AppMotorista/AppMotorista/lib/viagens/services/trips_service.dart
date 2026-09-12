import 'dart:convert';

import '../../auth/services/session_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../sync/local/outbox_local_store.dart';
import '../../sync/models/outbox_operation.dart';
import '../local/delivery_local_store.dart';
import '../local/trip_local_store.dart';
import '../models/delivery_read_result.dart';
import '../models/trip_detail.dart';
import '../models/trip_summary.dart';
import '../repositories/trips_repository.dart';
import 'delivery_operation_guid.dart';

abstract interface class DeliveryGateway {
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  });

  Future<TripDetail> get(String manifestGuid);
}

abstract interface class TripsGateway implements DeliveryGateway {
  Future<List<TripSummary>> list();
}

abstract interface class OfflineDataStatus {
  bool get listUsesSavedData;

  bool tripUsesSavedData(String manifestGuid);
}

abstract interface class PendingSyncStatus {
  Future<bool> hasPendingSync(String manifestGuid);
}

abstract interface class PendingOrderSyncStatus {
  Future<Set<int>> pendingSyncOrderIds({
    required String manifestGuid,
    required int stopId,
  });
}

abstract interface class PendingStopSyncStatus {
  Future<Set<int>> pendingSyncStopIds(String manifestGuid);
}

class OfflineTripUnavailableException implements Exception {
  const OfflineTripUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReadOnlyTripException implements Exception {
  const ReadOnlyTripException();

  @override
  String toString() => 'O aplicativo esta em modo somente leitura.';
}

class TripsService
    implements
        TripsGateway,
        OfflineDataStatus,
        PendingSyncStatus,
        PendingOrderSyncStatus,
        PendingStopSyncStatus {
  TripsService({
    required TripsRepository repository,
    required SessionController sessionController,
    required TripLocalStore localStore,
    required DeliveryLocalStore deliveryLocalStore,
    required OutboxLocalStore outboxLocalStore,
    String Function()? operationGuid,
    DateTime Function()? now,
    void Function()? outboxChanged,
    bool readOnly = false,
  }) : _repository = repository,
       _sessionController = sessionController,
       _localStore = localStore,
       _deliveryLocalStore = deliveryLocalStore,
       _outboxLocalStore = outboxLocalStore,
       _operationGuid = operationGuid ?? newDeliveryOperationGuid,
       _now = now ?? DateTime.now,
       _outboxChanged = outboxChanged,
       _readOnly = readOnly;

  final TripsRepository _repository;
  final SessionController _sessionController;
  final TripLocalStore _localStore;
  final DeliveryLocalStore _deliveryLocalStore;
  final OutboxLocalStore _outboxLocalStore;
  final String Function() _operationGuid;
  final DateTime Function() _now;
  final void Function()? _outboxChanged;
  final bool _readOnly;
  final Set<String> _tripsUsingSavedData = <String>{};
  bool _listUsesSavedData = false;
  final Set<String> _recoveredOutboxDrivers = <String>{};

  @override
  bool get listUsesSavedData => _listUsesSavedData;

  @override
  bool tripUsesSavedData(String manifestGuid) {
    return _tripsUsingSavedData.contains(manifestGuid);
  }

  @override
  Future<List<TripSummary>> list() async {
    final driverGuid = _driverGuid();
    if (_readOnly) {
      _listUsesSavedData = false;
      return _sessionController.authorized(_repository.list);
    }
    await _recoverOutbox(driverGuid);
    _listUsesSavedData = false;
    try {
      final remote = await _sessionController.authorized(_repository.list);
      return _mergePendingLocal(remote, driverGuid);
    } catch (error) {
      if (!_canUseSavedData(error)) rethrow;
      final saved = await _localStore.listSnapshots(driverGuid: driverGuid);
      if (saved.isEmpty) {
        throw const OfflineTripUnavailableException(
          'Sem conexão — nenhuma viagem salva. Abra a viagem com Internet '
          'antes de usá-la offline.',
        );
      }
      _listUsesSavedData = true;
      return saved;
    }
  }

  @override
  Future<TripDetail> get(String manifestGuid) async {
    final driverGuid = _driverGuid();
    if (_readOnly) {
      _tripsUsingSavedData.remove(manifestGuid);
      final remoteTrip = await _sessionController.authorized(
        (accessToken) => _repository.get(manifestGuid, accessToken),
      );
      if (remoteTrip.manifestGuid.isEmpty ||
          remoteTrip.manifestGuid != manifestGuid) {
        throw const FormatException('Snapshot de viagem invalido.');
      }
      return remoteTrip;
    }
    await _recoverOutbox(driverGuid);
    _tripsUsingSavedData.remove(manifestGuid);
    if (await _outboxLocalStore.hasPendingForManifest(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    )) {
      final saved = await _localStore.readSnapshot(
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
      );
      if (saved != null) {
        if (_listUsesSavedData) _tripsUsingSavedData.add(manifestGuid);
        return saved;
      }
    }
    late final TripDetail remoteTrip;
    try {
      remoteTrip = await _sessionController.authorized(
        (accessToken) => _repository.get(manifestGuid, accessToken),
      );
      if (remoteTrip.manifestGuid.isEmpty ||
          remoteTrip.manifestGuid != manifestGuid) {
        throw const FormatException('Snapshot de viagem inválido.');
      }
    } catch (error) {
      if (!_canUseSavedData(error)) rethrow;
      final saved = await _localStore.readSnapshot(
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
      );
      if (saved == null) {
        throw const OfflineTripUnavailableException(
          'Sem conexão — esta viagem precisa ser baixada antes de ser '
          'utilizada offline.',
        );
      }
      _tripsUsingSavedData.add(manifestGuid);
      return saved;
    }

    final reconciledTrip = _reconcileSyncedDeliveryReads(
      remoteTrip,
      await _outboxLocalStore.listSyncedDeliveryReads(
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
      ),
    );
    final synchronizedAt = _now();
    await _localStore.replaceSnapshot(
      driverGuid: driverGuid,
      trip: reconciledTrip,
      downloadedAt: synchronizedAt,
      lastServerSyncAt: synchronizedAt,
    );
    final saved = await _localStore.readSnapshot(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    );
    if (saved == null) {
      throw StateError('O snapshot gravado não pôde ser recuperado.');
    }
    return saved;
  }

  @override
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  }) async {
    if (_readOnly) throw const ReadOnlyTripException();
    final driverGuid = _driverGuid();
    await _recoverOutbox(driverGuid);
    final hadPendingOperations = await _outboxLocalStore.hasPendingForManifest(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    );
    final operationGuid = _operationGuid();
    final deviceDateTime = _now();
    final timezoneOffsetMinutes = deviceDateTime.timeZoneOffset.inMinutes;
    late final LocalDeliveryAcceptance local;
    try {
      local = await _deliveryLocalStore.registerRead(
        operationGuid: operationGuid,
        driverGuid: driverGuid,
        manifestGuid: manifestGuid,
        stopId: stopId,
        orderId: orderId,
        code: code,
        deviceDateTime: deviceDateTime,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
      );
    } on LocalDeliveryRejection catch (rejection) {
      return DeliveryReadResult(
        result: 'RECUSADA',
        responseCode: rejection.responseCode,
        message: rejection.message,
        replay: false,
      );
    }

    if (_tripsUsingSavedData.contains(manifestGuid) || hadPendingOperations) {
      _outboxChanged?.call();
      return _localAccepted(local);
    }

    final markedSending = await _outboxLocalStore.markSending(
      operationGuid,
      attemptedAt: deviceDateTime,
    );
    if (!markedSending) return _localAccepted(local);

    late final DeliveryReadResult result;
    try {
      result = await _sessionController.authorized(
        (accessToken) => _repository.registerRead(
          manifestGuid: manifestGuid,
          stopId: stopId,
          orderId: orderId,
          operationGuid: operationGuid,
          code: code,
          deviceDateTime: deviceDateTime,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          accessToken: accessToken,
        ),
      );
    } catch (error) {
      if (_canUseSavedData(error)) {
        await _outboxLocalStore.returnToPending(
          operationGuid,
          error: _safeError(error),
        );
        _outboxChanged?.call();
        return _localAccepted(local);
      }
      await _deliveryLocalStore.finishRejected(
        operationGuid: operationGuid,
        state: OutboxSyncState.rejected,
        responseCode: error is ApiException && error.statusCode != null
            ? 'HTTP_${error.statusCode}'
            : 'ERRO_TERMINAL',
        responseJson: null,
        error: _safeError(error),
      );
      rethrow;
    }
    if (result.isAccepted) {
      await _deliveryLocalStore.finishAccepted(
        operationGuid: operationGuid,
        finishedAt: _now(),
        serverOccurrenceGuid: result.occurrenceGuid,
        responseCode: result.responseCode,
        responseJson: jsonEncode(result.toJson()),
      );
      return result;
    }
    if (result.result == 'RECUSADA' || result.isConflict) {
      await _deliveryLocalStore.finishRejected(
        operationGuid: operationGuid,
        state: result.isConflict
            ? OutboxSyncState.conflict
            : OutboxSyncState.rejected,
        responseCode: result.responseCode,
        responseJson: jsonEncode(result.toJson()),
        error: result.message,
      );
      return result;
    }
    await _outboxLocalStore.returnToPending(
      operationGuid,
      error: 'Resposta remota sem resultado terminal reconhecido.',
    );
    _outboxChanged?.call();
    return _localAccepted(local);
  }

  @override
  Future<bool> hasPendingSync(String manifestGuid) {
    return _outboxLocalStore.hasPendingForManifest(
      driverGuid: _driverGuid(),
      manifestGuid: manifestGuid,
    );
  }

  @override
  Future<Set<int>> pendingSyncOrderIds({
    required String manifestGuid,
    required int stopId,
  }) {
    return _outboxLocalStore.pendingOrderIds(
      driverGuid: _driverGuid(),
      manifestGuid: manifestGuid,
      stopId: stopId,
    );
  }

  @override
  Future<Set<int>> pendingSyncStopIds(String manifestGuid) {
    return _outboxLocalStore.pendingStopIds(
      driverGuid: _driverGuid(),
      manifestGuid: manifestGuid,
    );
  }

  DeliveryReadResult _localAccepted(LocalDeliveryAcceptance local) {
    return DeliveryReadResult(
      result: 'ACEITA',
      responseCode: 'ACEITA_LOCAL',
      message: 'Etiqueta recepcionada com sucesso. Aguardando sincronização.',
      replay: false,
      occurrenceGuid: local.occurrenceGuid,
      type: local.type,
      orderId: local.orderId,
      pendingOrder: local.pendingOrder,
      pendingStop: local.pendingStop,
      awaitingSync: true,
    );
  }

  Future<List<TripSummary>> _mergePendingLocal(
    List<TripSummary> remote,
    String driverGuid,
  ) async {
    final pendingManifests = await _outboxLocalStore.pendingManifestGuids(
      driverGuid,
    );
    if (pendingManifests.isEmpty) return remote;
    final local = await _localStore.listSnapshots(driverGuid: driverGuid);
    final localPending = <String, TripSummary>{
      for (final trip in local)
        if (pendingManifests.contains(trip.manifestGuid))
          trip.manifestGuid: trip,
    };
    final merged = <TripSummary>[
      for (final trip in remote) localPending.remove(trip.manifestGuid) ?? trip,
      ...localPending.values,
    ];
    return List.unmodifiable(merged);
  }

  Future<void> _recoverOutbox(String driverGuid) async {
    if (!_recoveredOutboxDrivers.add(driverGuid)) return;
    try {
      await _outboxLocalStore.recoverInterruptedSending(driverGuid: driverGuid);
    } catch (_) {
      _recoveredOutboxDrivers.remove(driverGuid);
      rethrow;
    }
  }

  TripDetail _reconcileSyncedDeliveryReads(
    TripDetail remoteTrip,
    List<OutboxOperation> operations,
  ) {
    if (operations.isEmpty) return remoteTrip;
    final confirmedOccurrenceGuids = <String>{};
    for (final operation in operations) {
      final occurrenceGuid = _confirmedOccurrenceGuid(operation);
      if (occurrenceGuid != null) {
        confirmedOccurrenceGuids.add(occurrenceGuid.toUpperCase());
      }
    }
    if (confirmedOccurrenceGuids.isEmpty) return remoteTrip;

    return TripDetail(
      manifestGuid: remoteTrip.manifestGuid,
      manifestStatus: remoteTrip.manifestStatus,
      loadId: remoteTrip.loadId,
      description: remoteTrip.description,
      driverName: remoteTrip.driverName,
      originName: remoteTrip.originName,
      departureDate: remoteTrip.departureDate,
      departureTime: remoteTrip.departureTime,
      occurrenceCount: remoteTrip.occurrenceCount,
      stops: [
        for (final stop in remoteTrip.stops)
          _reconcileStop(stop, confirmedOccurrenceGuids),
      ],
    );
  }

  String? _confirmedOccurrenceGuid(OutboxOperation operation) {
    final persisted = operation.occurrenceGuid?.trim() ?? '';
    if (persisted.isNotEmpty) return persisted;
    final response = operation.responseJson;
    if (response == null || response.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(response);
      if (decoded is! Map<String, dynamic>) return null;
      final confirmed = decoded['ocorrencia_guid']?.toString().trim() ?? '';
      return confirmed.isEmpty ? null : confirmed;
    } on FormatException {
      return null;
    }
  }

  TripStop _reconcileStop(TripStop stop, Set<String> confirmedGuids) {
    final occurrences = [
      for (final occurrence in stop.occurrences)
        confirmedGuids.contains(occurrence.guid.toUpperCase()) &&
                occurrence.isPending
            ? occurrence.copyWith(status: 'E')
            : occurrence,
    ];
    final orders = [
      for (final order in stop.orders) _reconcileOrder(order, occurrences),
    ];
    final hasPending = occurrences.any((occurrence) => occurrence.isPending);
    return TripStop(
      id: stop.id,
      plannedOrder: stop.plannedOrder,
      status: occurrences.isEmpty ? stop.status : (hasPending ? 'P' : 'E'),
      clientName: stop.clientName,
      city: stop.city,
      state: stop.state,
      address: stop.address,
      orders: orders,
      occurrences: occurrences,
    );
  }

  TripOrder _reconcileOrder(
    TripOrder order,
    List<ManifestOccurrence> occurrences,
  ) {
    final orderOccurrences = occurrences
        .where((occurrence) => occurrence.orderId == order.id)
        .toList(growable: false);
    if (orderOccurrences.isEmpty) return order;
    return order.copyWith(
      status: orderOccurrences.any((occurrence) => occurrence.isPending)
          ? 'P'
          : 'E',
    );
  }

  String _driverGuid() {
    final driverGuid = _sessionController.session?.driver.guid.trim() ?? '';
    if (driverGuid.isEmpty) {
      throw const ApiException(
        'Sua sessão expirou. Entre novamente.',
        statusCode: 401,
      );
    }
    return driverGuid;
  }

  bool _canUseSavedData(Object error) {
    if (error is FormatException) return true;
    if (error is! ApiException) return false;
    final statusCode = error.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  String _safeError(Object error) {
    return error is ApiException
        ? error.message
        : 'Não foi possível confirmar a operação no servidor.';
  }
}
