import 'dart:async';

import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/services/delivery_scanner_controller.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1. leitura C aceita produz feedback de sucesso', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('C-1', pendingOrder: 0));
    final controller = _controller(gateway, [_occurrence('C-1')]);

    expect(await controller.submit('código-c'), ScanSubmitStatus.sent);

    expect(controller.feedback?.kind, DeliveryFeedbackKind.success);
    expect(controller.feedback?.message, 'Entrega registrada.');
  });

  test('2. ocorrência aceita passa de P para E', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('C-1', pendingOrder: 0));
    final controller = _controller(gateway, [_occurrence('C-1')]);

    await controller.submit('CÓDIGO-C');

    expect(controller.occurrences.single.status, 'E');
  });

  test('3. contadores são atualizados pela ocorrência aceita', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('C-1', pendingOrder: 1));
    final controller = _controller(gateway, [
      _occurrence('C-1'),
      _occurrence('C-2'),
    ]);

    await controller.submit('CÓDIGO-C');

    expect(controller.pending, 1);
    expect(controller.delivered, 1);
  });

  test('4. códigos C repetidos consomem ocorrências independentes', () async {
    var now = DateTime(2026, 8, 26, 14);
    final gateway = _FakeDeliveryGateway()
      ..results.addAll([
        _accepted('C-1', pendingOrder: 1),
        _accepted('C-2', pendingOrder: 0),
      ]);
    final controller = _controller(gateway, [
      _occurrence('C-1'),
      _occurrence('C-2'),
    ], now: () => now);

    await controller.submit('CÓDIGO-REPETIDO');
    now = now.add(const Duration(milliseconds: 801));
    await controller.submit('CÓDIGO-REPETIDO');

    expect(gateway.registerCalls, 2);
    expect(controller.delivered, 2);
    expect(controller.pending, 0);
  });

  test('5. leitura R altera somente a ocorrência/ROLO_ID devolvida', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('R-22', pendingOrder: 1, type: 'R'));
    final controller = _controller(gateway, [
      _occurrence('R-11', type: 'R', rollId: 11),
      _occurrence('R-22', type: 'R', rollId: 22),
    ]);

    await controller.submit('ROLO-22');

    expect(
      controller.occurrences.singleWhere((item) => item.rollId == 11).status,
      'P',
    );
    expect(
      controller.occurrences.singleWhere((item) => item.rollId == 22).status,
      'E',
    );
  });

  test('6. leitura recusada não altera estado local', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(
        const DeliveryReadResult(
          result: 'RECUSADA',
          responseCode: 'OUTRO_PEDIDO',
          message: 'Etiqueta pertence a outro pedido.',
          replay: false,
        ),
      );
    final controller = _controller(gateway, [_occurrence('C-1')]);

    await controller.submit('INVÁLIDA');

    expect(controller.occurrences.single.status, 'P');
    expect(controller.changed, isFalse);
    expect(controller.feedback?.kind, DeliveryFeedbackKind.warning);
    expect(controller.feedback?.message, 'Etiqueta pertence a outro pedido.');
  });

  test('7. bloqueia duplicidade enquanto envia e durante o debounce', () async {
    final pending = Completer<DeliveryReadResult>();
    final gateway = _FakeDeliveryGateway()..pendingResult = pending.future;
    final controller = _controller(gateway, [_occurrence('C-1')]);

    final first = controller.submit('CÓDIGO-C');
    expect(await controller.submit('CÓDIGO-C'), ScanSubmitStatus.ignoredBusy);
    pending.complete(_accepted('C-1', pendingOrder: 0));
    await first;
    expect(
      await controller.submit('CÓDIGO-C'),
      ScanSubmitStatus.ignoredDebounce,
    );
    expect(gateway.registerCalls, 1);
  });

  test('8. replay idempotente mantém sucesso sem entrega duplicada', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('C-1', pendingOrder: 0, replay: true));
    final controller = _controller(gateway, [_occurrence('C-1')]);

    await controller.submit('CÓDIGO-C');

    expect(controller.delivered, 1);
    expect(controller.feedback?.kind, DeliveryFeedbackKind.success);
    expect(controller.feedback?.message, contains('já processada'));
  });

  test('9. última ocorrência conclui pedido e parada', () async {
    final gateway = _FakeDeliveryGateway()
      ..results.add(_accepted('C-1', pendingOrder: 0, pendingStop: 0));
    final controller = _controller(gateway, [_occurrence('C-1')]);

    await controller.submit('CÓDIGO-C');

    expect(controller.order.status, 'E');
    expect(controller.stopCompleted, isTrue);
  });
}

DeliveryScannerController _controller(
  _FakeDeliveryGateway gateway,
  List<ManifestOccurrence> occurrences, {
  DateTime Function()? now,
}) {
  return DeliveryScannerController(
    gateway: gateway,
    manifestGuid: 'MANIFESTO-GUID',
    stopId: 7,
    order: const TripOrder(id: 123, status: 'P'),
    occurrences: occurrences,
    now: now,
  );
}

ManifestOccurrence _occurrence(String guid, {String type = 'C', int? rollId}) {
  return ManifestOccurrence(
    id: guid.hashCode,
    guid: guid,
    orderId: 123,
    productId: 10,
    type: type,
    code: 'CÓDIGO-C',
    quantity: '1',
    status: 'P',
    rollId: rollId,
  );
}

DeliveryReadResult _accepted(
  String occurrenceGuid, {
  required int pendingOrder,
  int pendingStop = 1,
  String type = 'C',
  bool replay = false,
}) {
  return DeliveryReadResult(
    result: 'ACEITA',
    responseCode: 'OK',
    message: 'Entrega registrada.',
    replay: replay,
    occurrenceGuid: occurrenceGuid,
    type: type,
    orderId: 123,
    pendingOrder: pendingOrder,
    pendingStop: pendingStop,
  );
}

class _FakeDeliveryGateway implements DeliveryGateway {
  final List<DeliveryReadResult> results = [];
  Future<DeliveryReadResult>? pendingResult;
  int registerCalls = 0;

  @override
  Future<TripDetail> get(String manifestGuid) {
    throw StateError('A atualização não era esperada neste teste.');
  }

  @override
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  }) async {
    registerCalls++;
    final pending = pendingResult;
    if (pending != null) {
      pendingResult = null;
      return pending;
    }
    return results.removeAt(0);
  }
}
