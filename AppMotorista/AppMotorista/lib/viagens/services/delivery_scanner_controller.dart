import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../models/delivery_read_result.dart';
import '../models/trip_detail.dart';
import 'trips_service.dart';

enum ScanSubmitStatus { sent, empty, ignoredBusy, ignoredDebounce }

enum DeliveryFeedbackKind { success, warning, error }

class DeliveryFeedback {
  const DeliveryFeedback({required this.kind, required this.message});

  final DeliveryFeedbackKind kind;
  final String message;
}

class DeliveryScannerController extends ChangeNotifier {
  DeliveryScannerController({
    required DeliveryGateway gateway,
    required this.manifestGuid,
    required this.stopId,
    required TripOrder order,
    required List<ManifestOccurrence> occurrences,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 800),
  }) : _gateway = gateway,
       _order = order,
       _occurrences = List.of(occurrences),
       _now = now ?? DateTime.now;

  final DeliveryGateway _gateway;
  final String manifestGuid;
  final int stopId;
  final Duration debounce;
  final DateTime Function() _now;

  TripOrder _order;
  List<ManifestOccurrence> _occurrences;
  bool _busy = false;
  bool _changed = false;
  bool _stopCompleted = false;
  String? _lastCode;
  DateTime? _lastReadAt;
  DeliveryFeedback? _feedback;

  TripOrder get order => _order;
  List<ManifestOccurrence> get occurrences => List.unmodifiable(_occurrences);
  bool get busy => _busy;
  bool get changed => _changed;
  bool get stopCompleted => _stopCompleted;
  DeliveryFeedback? get feedback => _feedback;
  int get pending => _occurrences.where((item) => item.isPending).length;
  int get delivered => _occurrences.where((item) => item.isDelivered).length;

  Future<ScanSubmitStatus> submit(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      _feedback = const DeliveryFeedback(
        kind: DeliveryFeedbackKind.error,
        message: 'Leia uma etiqueta válida.',
      );
      notifyListeners();
      return ScanSubmitStatus.empty;
    }
    if (_busy) return ScanSubmitStatus.ignoredBusy;

    final readAt = _now();
    if (_lastCode == code &&
        _lastReadAt != null &&
        readAt.difference(_lastReadAt!) < debounce) {
      return ScanSubmitStatus.ignoredDebounce;
    }

    _lastCode = code;
    _lastReadAt = readAt;
    _busy = true;
    _feedback = null;
    notifyListeners();
    try {
      final result = await _gateway.registerRead(
        manifestGuid: manifestGuid,
        stopId: stopId,
        orderId: _order.id,
        code: code,
      );
      if (result.isAccepted) {
        await _applyAccepted(result);
      } else {
        _feedback = DeliveryFeedback(
          kind: result.isConflict
              ? DeliveryFeedbackKind.error
              : DeliveryFeedbackKind.warning,
          message: _resultMessage(result),
        );
      }
    } on ApiException catch (error) {
      _feedback = DeliveryFeedback(
        kind: DeliveryFeedbackKind.error,
        message: error.message,
      );
    } on FormatException {
      _feedback = const DeliveryFeedback(
        kind: DeliveryFeedbackKind.error,
        message: 'O servidor enviou uma resposta inválida.',
      );
    } catch (_) {
      _feedback = const DeliveryFeedback(
        kind: DeliveryFeedbackKind.error,
        message: 'Não foi possível registrar a leitura. Verifique a conexão.',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
    return ScanSubmitStatus.sent;
  }

  Future<void> _applyAccepted(DeliveryReadResult result) async {
    final guid = result.occurrenceGuid;
    final index = guid == null
        ? -1
        : _occurrences.indexWhere(
            (item) => item.guid.toUpperCase() == guid.toUpperCase(),
          );
    if (index >= 0) {
      _occurrences[index] = _occurrences[index].copyWith(status: 'E');
    }
    if (result.pendingOrder == 0) {
      _order = _order.copyWith(status: 'E');
    }
    _stopCompleted = result.pendingStop == 0;
    _changed = true;

    final localNeedsRefresh =
        index < 0 ||
        (result.pendingOrder != null && result.pendingOrder != pending);
    if (localNeedsRefresh) {
      try {
        await _refreshFromBackend();
      } catch (_) {
        // A leitura já foi aceita. Uma falha na consulta de conferência não
        // pode transformar o sucesso gravado pelo servidor em recusa local.
      }
    }

    _feedback = DeliveryFeedback(
      kind: DeliveryFeedbackKind.success,
      message: result.replay
          ? 'Leitura já processada. ${_resultMessage(result)}'
          : _resultMessage(result),
    );
  }

  Future<void> _refreshFromBackend() async {
    final trip = await _gateway.get(manifestGuid);
    TripStop? stop;
    for (final candidate in trip.stops) {
      if (candidate.id == stopId) {
        stop = candidate;
        break;
      }
    }
    if (stop == null) return;
    TripOrder? order;
    for (final candidate in stop.orders) {
      if (candidate.id == _order.id) {
        order = candidate;
        break;
      }
    }
    if (order != null) _order = order;
    _occurrences = List.of(stop.occurrencesFor(_order.id));
  }

  String _resultMessage(DeliveryReadResult result) {
    return result.message.isEmpty
        ? (result.isAccepted
              ? 'Etiqueta entregue com sucesso.'
              : 'A leitura foi recusada pelo servidor.')
        : result.message;
  }
}
