import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/screens/stop_screen.dart';
import 'package:app_motorista/viagens/screens/trip_detail_screen.dart';
import 'package:app_motorista/viagens/services/trip_state_controller.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:app_motorista/viagens/utils/delivery_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pedido concluído e parada pendente retorna para Parada', (
    tester,
  ) async {
    final initialStop = _stop(
      id: 1,
      status: 'P',
      client: 'JULIO CESAR DE MAGELA',
      orders: [_order(17744), _order(17745)],
    );
    final refreshedStop = _stop(
      id: 1,
      status: 'P',
      client: 'JULIO CESAR DE MAGELA',
      orders: [_order(17744, completed: true), _order(17745)],
    );
    final gateway = _FakeGateway()
      ..readResults.add(_accepted(pendingStop: 1))
      ..getResults.add(_trip([refreshedStop]));

    await tester.pumpWidget(
      MaterialApp(
        home: StopScreen(
          manifestGuid: 'MANIFESTO',
          stop: initialStop,
          tripsService: gateway,
        ),
      ),
    );
    await tester.tap(find.text('ABRIR PEDIDO').first);
    await tester.pumpAndSettle();
    await _readPhysical(tester);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Parada'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Pedido recepcionado com sucesso.'), findsOneWidget);
    expect(
      _top(tester, 'Pedido 17745'),
      lessThan(_top(tester, 'Pedido 17744')),
    );
    final completedCard = tester.widget<Card>(
      find.byKey(const ValueKey('order-card-17744')),
    );
    expect(completedCard.color, completedDeliveryColor);
    expect(find.text('PEDIDO CONCLUÍDO'), findsOneWidget);
    final completedOrderButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('order-card-17744')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(completedOrderButton.onPressed, isNull);
    final completedOrderInkWells = tester.widgetList<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('order-card-17744')),
        matching: find.byType(InkWell),
      ),
    );
    expect(completedOrderInkWells.every((item) => item.onTap == null), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido recepcionado com sucesso.'), findsNothing);
  });

  testWidgets('pedido e parada concluídos retornam diretamente para Viagem', (
    tester,
  ) async {
    final initialStop = _stop(
      id: 1,
      status: 'P',
      client: 'JULIO CESAR DE MAGELA',
      orders: [_order(17744)],
    );
    final nextStop = _stop(
      id: 2,
      status: 'P',
      client: 'PROXIMO CLIENTE',
      orders: [_order(17745)],
    );
    final completedStop = _stop(
      id: 1,
      status: 'E',
      client: 'JULIO CESAR DE MAGELA',
      orders: [_order(17744, completed: true)],
    );
    final gateway = _FakeGateway()
      ..getResults.addAll([
        _trip([initialStop, nextStop]),
        _trip([completedStop, nextStop]),
      ])
      ..readResults.add(_accepted(pendingStop: 0));

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          manifestGuid: 'MANIFESTO',
          tripsService: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABRIR PARADA').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABRIR PEDIDO'));
    await tester.pumpAndSettle();
    await _readPhysical(tester);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Parada'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Pedido recepcionado com sucesso.'), findsOneWidget);
    final completedOrderCard = tester.widget<Card>(
      find.byKey(const ValueKey('order-card-17744')),
    );
    expect(completedOrderCard.color, completedDeliveryColor);

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Viagem'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Parada'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Pedido'), findsNothing);
    expect(
      _top(tester, 'PROXIMO CLIENTE'),
      lessThan(_top(tester, 'JULIO CESAR DE MAGELA')),
    );
    final completedCard = tester.widget<Card>(
      find.byKey(const ValueKey('stop-card-1')),
    );
    expect(completedCard.color, completedDeliveryColor);
    expect(find.text('PARADA CONCLUÍDA'), findsOneWidget);
    final completedStopButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('stop-card-1')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(completedStopButton.onPressed, isNull);
    final completedStopInkWells = tester.widgetList<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('stop-card-1')),
        matching: find.byType(InkWell),
      ),
    );
    expect(completedStopInkWells.every((item) => item.onTap == null), isTrue);
  });

  testWidgets('pendência fica azul somente na Parada concluída que a contém', (
    tester,
  ) async {
    final firstStop = _stop(
      id: 1,
      status: 'E',
      client: 'CLIENTE COM PENDENCIA',
      orders: [_order(17744, completed: true)],
    );
    final secondStop = _stop(
      id: 2,
      status: 'E',
      client: 'CLIENTE CONFIRMADO',
      orders: [_order(17745, completed: true)],
    );
    final pendingGateway = _FakeGateway()
      ..pendingStopIds = const {1}
      ..getResults.add(_trip([firstStop, secondStop]));

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          key: const ValueKey('pending-stops'),
          manifestGuid: 'MANIFESTO',
          tripsService: pendingGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pendingCard = find.byKey(const ValueKey('stop-card-1'));
    final confirmedCard = find.byKey(const ValueKey('stop-card-2'));
    expect(tester.widget<Card>(pendingCard).color, pendingSyncDeliveryColor);
    expect(
      find.descendant(
        of: pendingCard,
        matching: find.text('Aguardando sincronização'),
      ),
      findsOneWidget,
    );
    expect(tester.widget<Card>(confirmedCard).color, completedDeliveryColor);
    expect(
      find.descendant(
        of: confirmedCard,
        matching: find.text('Aguardando sincronização'),
      ),
      findsNothing,
    );

    final confirmedGateway = _FakeGateway()
      ..getResults.add(_trip([firstStop, secondStop]));
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailScreen(
          key: const ValueKey('confirmed-stops'),
          manifestGuid: 'MANIFESTO',
          tripsService: confirmedGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Card>(find.byKey(const ValueKey('stop-card-1'))).color,
      completedDeliveryColor,
    );
    expect(
      tester.widget<Card>(find.byKey(const ValueKey('stop-card-2'))).color,
      completedDeliveryColor,
    );
    expect(find.text('Aguardando sincronização'), findsNothing);
  });
  testWidgets(
    'projeção reativa preserva amarelo nas paradas ja sincronizadas',
    (tester) async {
      final syncedStop = _stop(
        id: 1,
        status: 'E',
        client: 'CLIENTE SINCRONIZADO',
        orders: [_order(17744, completed: true)],
      );
      final pendingStop = _stop(
        id: 2,
        status: 'E',
        client: 'CLIENTE OFFLINE',
        orders: [_order(17745, completed: true)],
      );
      final trip = _trip([syncedStop, pendingStop]);
      final controller = TripStateController(
        scope: 'homologacao',
        activeDriverGuid: () => 'driver',
        readSnapshot: ({required driverGuid, required manifestGuid}) async =>
            trip,
        pendingStopIds: ({required driverGuid, required manifestGuid}) async =>
            {2},
        pendingOrderIds:
            ({
              required driverGuid,
              required manifestGuid,
              required stopId,
            }) async => stopId == 2 ? {17745} : const {},
      );
      final gateway = _FakeGateway()..getResults.add(trip);

      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailScreen(
            manifestGuid: 'MANIFESTO',
            tripsService: gateway,
            tripStateController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNWidgets(2));
      await controller.publish(driverGuid: 'driver', manifestGuid: 'MANIFESTO');
      await tester.pumpAndSettle();

      expect(
        tester.widget<Card>(find.byKey(const ValueKey('stop-card-1'))).color,
        completedDeliveryColor,
      );
      expect(
        tester.widget<Card>(find.byKey(const ValueKey('stop-card-2'))).color,
        pendingSyncDeliveryColor,
      );
    },
  );

  testWidgets('projeção reativa isola pedido pendente na tela Parada', (
    tester,
  ) async {
    final stop = _stop(
      id: 1,
      status: 'E',
      client: 'CLIENTE',
      orders: [_order(17744, completed: true), _order(17745, completed: true)],
    );
    final trip = _trip([stop]);
    final controller = TripStateController(
      scope: 'homologacao',
      activeDriverGuid: () => 'driver',
      readSnapshot: ({required driverGuid, required manifestGuid}) async =>
          trip,
      pendingStopIds: ({required driverGuid, required manifestGuid}) async => {
        1,
      },
      pendingOrderIds:
          ({
            required driverGuid,
            required manifestGuid,
            required stopId,
          }) async => {17745},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StopScreen(
          manifestGuid: 'MANIFESTO',
          stop: stop,
          tripsService: _FakeGateway(),
          tripStateController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await controller.publish(driverGuid: 'driver', manifestGuid: 'MANIFESTO');
    await tester.pumpAndSettle();

    expect(
      tester.widget<Card>(find.byKey(const ValueKey('order-card-17744'))).color,
      completedDeliveryColor,
    );
    expect(
      tester.widget<Card>(find.byKey(const ValueKey('order-card-17745'))).color,
      pendingSyncDeliveryColor,
    );
  });
}

Future<void> _readPhysical(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'C');
  await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
}

double _top(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}

TripOrder _order(int id, {bool completed = false}) {
  return TripOrder(id: id, status: completed ? 'E' : 'P');
}

TripStop _stop({
  required int id,
  required String status,
  required String client,
  required List<TripOrder> orders,
}) {
  return TripStop(
    id: id,
    plannedOrder: id,
    status: status,
    clientName: client,
    city: 'Ubá',
    state: 'MG',
    address: '',
    orders: orders,
    occurrences: [
      for (final order in orders)
        ManifestOccurrence(
          id: order.id,
          guid: 'OC-${order.id}',
          orderId: order.id,
          productId: order.id,
          type: 'C',
          code: 'C1',
          quantity: '1',
          status: order.status,
        ),
    ],
  );
}

TripDetail _trip(List<TripStop> stops) {
  return TripDetail(
    manifestGuid: 'MANIFESTO',
    manifestStatus: 'L',
    loadId: 527,
    description: 'TESTE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    stops: stops,
    occurrenceCount: stops.fold(
      0,
      (total, stop) => total + stop.occurrences.length,
    ),
  );
}

DeliveryReadResult _accepted({required int pendingStop}) {
  return DeliveryReadResult(
    result: 'ACEITA',
    responseCode: 'OK',
    message: 'Entrega registrada com sucesso.',
    replay: false,
    occurrenceGuid: 'OC-17744',
    orderId: 17744,
    pendingOrder: 0,
    pendingStop: pendingStop,
  );
}

class _FakeGateway implements DeliveryGateway, PendingStopSyncStatus {
  final List<TripDetail> getResults = [];
  final List<DeliveryReadResult> readResults = [];
  Set<int> pendingStopIds = const {};

  @override
  Future<Set<int>> pendingSyncStopIds(String manifestGuid) async {
    return pendingStopIds;
  }

  @override
  Future<TripDetail> get(String manifestGuid) async {
    return getResults.removeAt(0);
  }

  @override
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  }) async {
    return readResults.removeAt(0);
  }
}
