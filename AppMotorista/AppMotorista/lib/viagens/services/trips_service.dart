import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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
import 'trip_state_controller.dart';

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

class TripsService extends ChangeNotifier
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
    TripStateController? tripStateController,
    bool readOnly = false,
    bool automaticDownload = true,
  }) : _repository = repository,
       _sessionController = sessionController,
       _localStore = localStore,
       _deliveryLocalStore = deliveryLocalStore,
       _outboxLocalStore = outboxLocalStore,
       _operationGuid = operationGuid ?? newDeliveryOperationGuid,
       _now = now ?? DateTime.now,
       _outboxChanged = outboxChanged,
       _tripStateController = tripStateController,
       _readOnly = readOnly,
       _automaticDownload = automaticDownload;

  final TripsRepository _repository;
  final SessionController _sessionController;
  final TripLocalStore _localStore;
  final DeliveryLocalStore _deliveryLocalStore;
  final OutboxLocalStore _outboxLocalStore;
  final String Function() _operationGuid;
  final DateTime Function() _now;
  final void Function()? _outboxChanged;
  final TripStateController? _tripStateController;
  final bool _readOnly;
  final bool _automaticDownload;
  final Set<String> _tripsUsingSavedData = <String>{};
  bool _listUsesSavedData = false;
  final Set<String> _recoveredOutboxDrivers = <String>{};
  final Set<String> _downloadsInProgress = <String>{};
  final Set<String> _downloadsAttempted = <String>{};

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
      final merged = await _mergeLocalVisualState(remote, driverGuid);
      if (_automaticDownload) _downloadMissingSnapshots(remote, driverGuid);
      return merged;
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
        await _publishLocalState(driverGuid, manifestGuid);
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
    notifyListeners();
    await _publishLocalState(driverGuid, manifestGuid);
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

    await _publishLocalState(driverGuid, manifestGuid);

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
          occurrenceGuid: local.occurrenceGuid,
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
      await _publishLocalState(driverGuid, manifestGuid);
      rethrow;
    }
    if (result.isAccepted) {
      if (!_matchesLocalOccurrenceGuid(local.occurrenceGuid, result)) {
        const error =
            'A ocorrência confirmada pelo servidor diverge da operação local.';
        await _deliveryLocalStore.finishRejected(
          operationGuid: operationGuid,
          state: OutboxSyncState.conflict,
          responseCode: result.responseCode,
          responseJson: jsonEncode(result.toJson()),
          error: error,
        );
        await _publishLocalState(driverGuid, manifestGuid);
        return DeliveryReadResult(
          result: 'CONFLITO',
          responseCode: 'OCORRENCIA_GUID_DIVERGENTE',
          message: error,
          replay: result.replay,
          occurrenceGuid: result.occurrenceGuid,
        );
      }
      await _deliveryLocalStore.finishAccepted(
        operationGuid: operationGuid,
        finishedAt: _now(),
        serverOccurrenceGuid: result.occurrenceGuid,
        responseCode: result.responseCode,
        responseJson: jsonEncode(result.toJson()),
      );
      await _publishLocalState(driverGuid, manifestGuid);
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
      await _publishLocalState(driverGuid, manifestGuid);
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

  Future<List<TripSummary>> _mergeLocalVisualState(
    List<TripSummary> remote,
    String driverGuid,
  ) async {
    final pendingManifests = await _outboxLocalStore.pendingManifestGuids(
      driverGuid,
    );
    final local = await _localStore.listSnapshots(driverGuid: driverGuid);
    final localByManifest = <String, TripSummary>{
      for (final trip in local) trip.manifestGuid: trip,
    };
    final downloadStates = await _localStore.downloadStates(
      driverGuid: driverGuid,
    );
    return List.unmodifiable([
      for (final trip in remote)
        _withLocalVisualState(
          trip,
          localByManifest[trip.manifestGuid],
          pendingManifests.contains(trip.manifestGuid),
          downloadStates[trip.manifestGuid],
        ),
    ]);
  }

  TripSummary _withLocalVisualState(
    TripSummary remote,
    TripSummary? local,
    bool hasPendingSync,
    String? downloadState,
  ) {
    final offlineAvailability = local != null
        ? OfflineAvailability.available
        : downloadState == 'failed'
        ? OfflineAvailability.failed
        : OfflineAvailability.pending;
    if (local == null) {
      return TripSummary(
        manifestGuid: remote.manifestGuid,
        loadId: remote.loadId,
        description: remote.description,
        stopCount: remote.stopCount,
        occurrenceCount: remote.occurrenceCount,
        departureDate: remote.departureDate,
        departureTime: remote.departureTime,
        releasedAt: remote.releasedAt,
        awaitingSync: hasPendingSync,
        offlineAvailability: offlineAvailability,
      );
    }
    return TripSummary(
      manifestGuid: remote.manifestGuid,
      loadId: remote.loadId,
      description: remote.description,
      stopCount: remote.stopCount,
      occurrenceCount: remote.occurrenceCount,
      departureDate: remote.departureDate,
      departureTime: remote.departureTime,
      releasedAt: remote.releasedAt,
      locallyCompleted: local.locallyCompleted,
      awaitingSync: hasPendingSync,
      offlineAvailability: offlineAvailability,
    );
  }

  void _downloadMissingSnapshots(List<TripSummary> trips, String driverGuid) {
    for (final trip in trips) {
      final key = '$driverGuid/${trip.manifestGuid}';
      if (_downloadsInProgress.contains(key) ||
          _downloadsAttempted.contains(key)) {
        continue;
      }
      _downloadsAttempted.add(key);
      _downloadsInProgress.add(key);
      unawaited(_downloadSnapshot(trip, driverGuid, key));
    }
  }

  Future<void> _downloadSnapshot(
    TripSummary trip,
    String driverGuid,
    String key,
  ) async {
    try {
      if (await _localStore.hasCompleteSnapshot(
        driverGuid: driverGuid,
        manifestGuid: trip.manifestGuid,
      )) {
        await _localStore.clearDownloadState(
          driverGuid: driverGuid,
          manifestGuid: trip.manifestGuid,
        );
        return;
      }
      await _localStore.markDownloadPending(
        driverGuid: driverGuid,
        manifestGuid: trip.manifestGuid,
        updatedAt: _now(),
      );
      notifyListeners();
      final detail = await _sessionController.authorized(
        (accessToken) => _repository.get(trip.manifestGuid, accessToken),
      );
      if (detail.manifestGuid != trip.manifestGuid ||
          detail.manifestGuid.isEmpty) {
        throw const FormatException('Snapshot de viagem inválido.');
      }
      final reconciled = _reconcileSyncedDeliveryReads(
        detail,
        await _outboxLocalStore.listSyncedDeliveryReads(
          driverGuid: driverGuid,
          manifestGuid: trip.manifestGuid,
        ),
      );
      final syncedAt = _now();
      await _localStore.replaceSnapshot(
        driverGuid: driverGuid,
        trip: reconciled,
        downloadedAt: syncedAt,
        lastServerSyncAt: syncedAt,
      );
      await _publishLocalState(driverGuid, trip.manifestGuid);
    } catch (error) {
      if (!await _localStore.hasCompleteSnapshot(
        driverGuid: driverGuid,
        manifestGuid: trip.manifestGuid,
      )) {
        await _localStore.markDownloadFailed(
          driverGuid: driverGuid,
          manifestGuid: trip.manifestGuid,
          errorMessage: _safeError(error),
          updatedAt: _now(),
        );
      }
    } finally {
      _downloadsInProgress.remove(key);
      notifyListeners();
    }
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

  Future<void> _publishLocalState(
    String driverGuid,
    String manifestGuid,
  ) async {
    await _tripStateController?.publish(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    );
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

  bool _matchesLocalOccurrenceGuid(
    String localOccurrenceGuid,
    DeliveryReadResult result,
  ) {
    final localGuid = localOccurrenceGuid.trim();
    final serverGuid = result.occurrenceGuid?.trim() ?? '';
    return localGuid.isNotEmpty &&
        serverGuid.isNotEmpty &&
        localGuid.toUpperCase() == serverGuid.toUpperCase();
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
