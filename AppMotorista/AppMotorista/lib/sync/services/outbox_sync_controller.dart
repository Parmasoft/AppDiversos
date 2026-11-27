import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../auth/services/session_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../viagens/local/delivery_local_store.dart';
import '../../viagens/models/delivery_read_result.dart';
import '../local/outbox_local_store.dart';
import '../models/outbox_operation.dart';
import 'outbox_retry_policy.dart';

typedef PersistedOperationSender =
    Future<DeliveryReadResult> Function(
      OutboxOperation operation,
      String accessToken,
    );
typedef ServerReachabilityProbe = Future<bool> Function();
typedef ManifestStateCommitted =
    Future<void> Function(String driverGuid, String manifestGuid);

class OutboxProcessingReport {
  const OutboxProcessingReport({
    required this.attempted,
    required this.confirmed,
    required this.rejected,
    required this.conflicts,
    this.nextAttemptAt,
  });

  static const empty = OutboxProcessingReport(
    attempted: 0,
    confirmed: 0,
    rejected: 0,
    conflicts: 0,
  );

  final int attempted;
  final int confirmed;
  final int rejected;
  final int conflicts;
  final DateTime? nextAttemptAt;

  bool get reconciledAny => confirmed + rejected + conflicts > 0;
}

class OutboxSyncController extends ChangeNotifier {
  OutboxSyncController({
    required SessionController sessionController,
    required OutboxLocalStore outboxLocalStore,
    required DeliveryLocalStore deliveryLocalStore,
    required PersistedOperationSender send,
    OutboxRetryPolicy retryPolicy = const OutboxRetryPolicy(),
    DateTime Function()? now,
    ServerReachabilityProbe? serverReachabilityProbe,
    ManifestStateCommitted? onManifestStateCommitted,
    Duration reachabilityInterval = const Duration(seconds: 10),
  }) : _sessionController = sessionController,
       _outboxLocalStore = outboxLocalStore,
       _deliveryLocalStore = deliveryLocalStore,
       _send = send,
       _retryPolicy = retryPolicy,
       _now = now ?? DateTime.now,
       _serverReachabilityProbe = serverReachabilityProbe,
       _onManifestStateCommitted = onManifestStateCommitted,
       _reachabilityInterval = reachabilityInterval;

  final SessionController _sessionController;
  final OutboxLocalStore _outboxLocalStore;
  final DeliveryLocalStore _deliveryLocalStore;
  final PersistedOperationSender _send;
  final OutboxRetryPolicy _retryPolicy;
  final DateTime Function() _now;
  final ServerReachabilityProbe? _serverReachabilityProbe;
  final Duration _reachabilityInterval;
  final ManifestStateCommitted? _onManifestStateCommitted;

  Future<OutboxProcessingReport>? _activeRun;
  Timer? _retryTimer;
  Timer? _reachabilityTimer;
  bool _started = false;
  bool _disposed = false;
  bool _runAgain = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _sessionController.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  void appResumed() {
    if (_started && !_disposed) _trigger();
  }

  void outboxChanged() {
    if (_started && !_disposed) _trigger();
  }

  Future<OutboxProcessingReport> processNow() {
    final active = _activeRun;
    if (active != null) return active;

    final completer = Completer<OutboxProcessingReport>();
    _activeRun = completer.future;
    unawaited(() async {
      try {
        final report = await _processInOrder();
        if (report.reconciledAny && !_disposed) notifyListeners();
        _schedule(report.nextAttemptAt);
        completer.complete(report);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _activeRun = null;
        if (_runAgain && _started && !_disposed) {
          _runAgain = false;
          scheduleMicrotask(_trigger);
        }
      }
    }());
    return completer.future;
  }

  Future<OutboxProcessingReport> _processInOrder() async {
    final driverGuid = _driverGuid();
    if (driverGuid == null) return OutboxProcessingReport.empty;

    await _outboxLocalStore.recoverInterruptedSending(driverGuid: driverGuid);
    var attempted = 0;
    var confirmed = 0;
    var rejected = 0;
    var conflicts = 0;
    DateTime? nextAttemptAt;

    while (true) {
      if (_driverGuid() != driverGuid) break;
      final operation = await _outboxLocalStore.nextInOrder(
        driverGuid: driverGuid,
      );
      if (operation == null) break;

      final now = _now();
      if (operation.state == OutboxSyncState.retry &&
          operation.nextAttemptAt?.isAfter(now) == true) {
        nextAttemptAt = operation.nextAttemptAt;
        break;
      }

      final marked = await _outboxLocalStore.markSending(
        operation.operationGuid,
        attemptedAt: now,
      );
      if (!marked) continue;
      attempted++;

      DeliveryReadResult result;
      try {
        result = await _sessionController.authorized(
          (accessToken) => _send(operation, accessToken),
        );
      } catch (error) {
        if (_isTerminalHttpFailure(error)) {
          await _deliveryLocalStore.finishRejected(
            operationGuid: operation.operationGuid,
            state: OutboxSyncState.rejected,
            responseCode: 'HTTP_${(error as ApiException).statusCode}',
            responseJson: null,
            error: _safeError(error),
          );
          await _publishCommitted(operation);
          rejected++;
          continue;
        }
        nextAttemptAt = await _retry(operation, error);
        break;
      }

      if (result.isAccepted &&
          !_matchesOperationOccurrence(operation, result)) {
        await _deliveryLocalStore.finishRejected(
          operationGuid: operation.operationGuid,
          state: OutboxSyncState.conflict,
          responseCode: result.responseCode,
          responseJson: jsonEncode(result.toJson()),
          error:
              'A ocorrência confirmada pelo servidor diverge da operação local.',
        );
        await _publishCommitted(operation);
        conflicts++;
        continue;
      }

      if (result.isAccepted) {
        try {
          await _deliveryLocalStore.finishAccepted(
            operationGuid: operation.operationGuid,
            finishedAt: _now(),
            serverOccurrenceGuid: result.occurrenceGuid,
            responseCode: result.responseCode,
            responseJson: jsonEncode(result.toJson()),
          );
          await _publishCommitted(operation);
          confirmed++;
          continue;
        } catch (error) {
          nextAttemptAt = await _retry(operation, error);
          break;
        }
      }

      if (result.result == 'RECUSADA' || result.isConflict) {
        final state = result.isConflict
            ? OutboxSyncState.conflict
            : OutboxSyncState.rejected;
        await _deliveryLocalStore.finishRejected(
          operationGuid: operation.operationGuid,
          state: state,
          responseCode: result.responseCode,
          responseJson: jsonEncode(result.toJson()),
          error: result.message,
        );
        await _publishCommitted(operation);
        if (result.isConflict) {
          conflicts++;
        } else {
          rejected++;
        }
        continue;
      }

      nextAttemptAt = await _retry(
        operation,
        const FormatException('Resposta remota sem resultado reconhecido.'),
      );
      break;
    }

    return OutboxProcessingReport(
      attempted: attempted,
      confirmed: confirmed,
      rejected: rejected,
      conflicts: conflicts,
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<DateTime> _retry(OutboxOperation operation, Object error) async {
    final attempt = operation.attemptCount + 1;
    final delay = _retryPolicy.delayFor(
      operationGuid: operation.operationGuid,
      attempt: attempt,
    );
    final nextAttemptAt = _now().add(delay);
    await _outboxLocalStore.scheduleRetry(
      operation.operationGuid,
      nextAttemptAt: nextAttemptAt,
      error: _safeError(error),
    );
    return nextAttemptAt;
  }

  Future<void> _publishCommitted(OutboxOperation operation) async {
    await _onManifestStateCommitted?.call(
      operation.driverGuid,
      operation.manifestGuid,
    );
  }

  bool _isTerminalHttpFailure(Object error) {
    if (error is! ApiException) return false;
    final statusCode = error.statusCode;
    return statusCode != null &&
        statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 401 &&
        statusCode != 408 &&
        statusCode != 425 &&
        statusCode != 429;
  }

  String _safeError(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;
    return 'Não foi possível confirmar a operação no servidor.';
  }

  String? _driverGuid() {
    if (_sessionController.state != SessionState.authenticated) return null;
    final value = _sessionController.session?.driver.guid.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  void _handleSessionChanged() {
    if (_driverGuid() == null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    _trigger();
    unawaited(_checkReachability());
  }

  Future<void> _checkReachability() async {
    if (!_started || _disposed || _activeRun != null) return;
    final probe = _serverReachabilityProbe;
    final driverGuid = _driverGuid();
    if (probe == null || driverGuid == null) return;
    if (!await _outboxLocalStore.hasPendingForDriver(driverGuid)) return;
    bool reachable;
    try {
      reachable = await probe();
    } catch (_) {
      return;
    }
    if (!reachable || _driverGuid() != driverGuid || _disposed) return;
    await _outboxLocalStore.makeRetriesReady(driverGuid);
    _trigger();
  }

  void _trigger() {
    if (_activeRun != null) {
      _runAgain = true;
      return;
    }
    unawaited(
      processNow().catchError((Object _) => OutboxProcessingReport.empty),
    );
  }

  void _schedule(DateTime? nextAttemptAt) {
    if (!_started || _disposed) return;
    _retryTimer?.cancel();
    _reachabilityTimer?.cancel();
    _retryTimer = null;
    _reachabilityTimer = null;
    if (nextAttemptAt == null || _driverGuid() == null) return;
    _startReachabilityMonitor();
    final delay = nextAttemptAt.difference(_now());
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, _trigger);
  }

  void _startReachabilityMonitor() {
    if (_serverReachabilityProbe == null || _reachabilityTimer != null) return;
    _reachabilityTimer = Timer.periodic(_reachabilityInterval, (_) {
      unawaited(_checkReachability());
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _runAgain = false;
    _retryTimer?.cancel();
    if (_started) {
      _sessionController.removeListener(_handleSessionChanged);
    }
    super.dispose();
  }
}

bool _matchesOperationOccurrence(
  OutboxOperation operation,
  DeliveryReadResult result,
) {
  final localGuid = operation.occurrenceGuid?.trim() ?? '';
  final serverGuid = result.occurrenceGuid?.trim() ?? '';
  return localGuid.isNotEmpty &&
      serverGuid.isNotEmpty &&
      localGuid.toUpperCase() == serverGuid.toUpperCase();
}
