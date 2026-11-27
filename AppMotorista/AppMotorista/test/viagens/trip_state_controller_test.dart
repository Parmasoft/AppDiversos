import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/models/trip_summary.dart';
import 'package:app_motorista/viagens/services/trip_state_controller.dart';

void main() {
  test('publica apenas o snapshot do motorista ativo', () async {
    final controller = TripStateController(
      scope: 'homologacao',
      activeDriverGuid: () => 'driver-a',
      readSnapshot: ({required driverGuid, required manifestGuid}) async =>
          _trip(manifestGuid, 'P'),
      pendingStopIds: ({required driverGuid, required manifestGuid}) async => {
        1,
      },
      pendingOrderIds:
          ({
            required driverGuid,
            required manifestGuid,
            required stopId,
          }) async => {1},
    );

    await controller.publish(driverGuid: 'driver-b', manifestGuid: 'manifesto');
    expect(
      controller.snapshotFor(driverGuid: 'driver-b', manifestGuid: 'manifesto'),
      isNull,
    );

    await controller.publish(driverGuid: 'driver-a', manifestGuid: 'manifesto');
    final state = controller.activeSnapshotFor('manifesto');
    expect(state, isNotNull);
    expect(state!.awaitingSync, isTrue);
  });

  test('ignora leitura antiga que termina depois da mais recente', () async {
    final first = Completer<TripDetail?>();
    final second = Completer<TripDetail?>();
    var reads = 0;
    final controller = TripStateController(
      scope: 'homologacao',
      activeDriverGuid: () => 'driver-a',
      readSnapshot: ({required driverGuid, required manifestGuid}) {
        reads++;
        return reads == 1 ? first.future : second.future;
      },
      pendingStopIds: ({required driverGuid, required manifestGuid}) async =>
          const {},
      pendingOrderIds:
          ({
            required driverGuid,
            required manifestGuid,
            required stopId,
          }) async => const {},
    );

    final oldPublish = controller.publish(
      driverGuid: 'driver-a',
      manifestGuid: 'manifesto',
    );
    final newPublish = controller.publish(
      driverGuid: 'driver-a',
      manifestGuid: 'manifesto',
    );
    second.complete(_trip('manifesto', 'E'));
    await newPublish;
    first.complete(_trip('manifesto', 'P'));
    await oldPublish;

    expect(
      controller.activeSnapshotFor('manifesto')!.trip.stops.single.status,
      'E',
    );
  });

  test('mantem pendencia offline granular por parada e pedido', () async {
    final controller = TripStateController(
      scope: 'homologacao',
      activeDriverGuid: () => 'driver-a',
      readSnapshot: ({required driverGuid, required manifestGuid}) async =>
          _tripWithTwoStops(manifestGuid),
      pendingStopIds: ({required driverGuid, required manifestGuid}) async => {
        2,
      },
      pendingOrderIds:
          ({
            required driverGuid,
            required manifestGuid,
            required stopId,
          }) async => stopId == 2 ? {22} : const {},
    );

    await controller.publish(driverGuid: 'driver-a', manifestGuid: 'manifesto');

    final state = controller.activeSnapshotFor('manifesto')!;
    expect(state.awaitingSync, isTrue);
    expect(state.pendingStopIds, {2});
    expect(state.pendingOrderIdsByStop[1], isEmpty);
    expect(state.pendingOrderIdsByStop[2], {22});
  });

  test(
    'publica disponibilidade offline apos snapshot SQLite completo',
    () async {
      final controller = TripStateController(
        scope: 'homologacao',
        activeDriverGuid: () => 'driver-a',
        readSnapshot: ({required driverGuid, required manifestGuid}) async =>
            _trip(manifestGuid, 'E'),
        pendingStopIds: ({required driverGuid, required manifestGuid}) async =>
            const {},
        pendingOrderIds:
            ({
              required driverGuid,
              required manifestGuid,
              required stopId,
            }) async => const {},
      );

      await controller.publish(
        driverGuid: 'driver-a',
        manifestGuid: 'manifesto',
      );

      expect(
        controller.activeSnapshotFor('manifesto')!.offlineAvailability,
        OfflineAvailability.available,
      );
    },
  );
}

TripDetail _trip(String manifestGuid, String status) => TripDetail(
  manifestGuid: manifestGuid,
  manifestStatus: 'L',
  loadId: 779,
  description: 'Teste',
  driverName: 'Motorista',
  originName: 'Origem',
  occurrenceCount: 1,
  stops: [
    TripStop(
      id: 1,
      plannedOrder: 1,
      status: status,
      clientName: 'Cliente',
      city: 'Cidade',
      state: 'MG',
      address: '',
      orders: [TripOrder(id: 1, status: status)],
      occurrences: [
        ManifestOccurrence(
          id: 1,
          guid: 'occurrence',
          orderId: 1,
          productId: 1,
          type: 'P',
          code: 'codigo',
          quantity: '1',
          status: status,
        ),
      ],
    ),
  ],
);

TripDetail _tripWithTwoStops(String manifestGuid) => TripDetail(
  manifestGuid: manifestGuid,
  manifestStatus: 'L',
  loadId: 780,
  description: 'Teste',
  driverName: 'Motorista',
  originName: 'Origem',
  occurrenceCount: 2,
  stops: [
    TripStop(
      id: 1,
      plannedOrder: 1,
      status: 'E',
      clientName: 'Sincronizado',
      city: 'Cidade',
      state: 'MG',
      address: '',
      orders: [TripOrder(id: 11, status: 'E')],
      occurrences: const [],
    ),
    TripStop(
      id: 2,
      plannedOrder: 2,
      status: 'E',
      clientName: 'Pendente',
      city: 'Cidade',
      state: 'MG',
      address: '',
      orders: [TripOrder(id: 22, status: 'E')],
      occurrences: const [],
    ),
  ],
);
