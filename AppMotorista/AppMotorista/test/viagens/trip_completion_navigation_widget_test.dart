import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/models/trip_summary.dart';
import 'package:app_motorista/viagens/screens/trips_screen.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets(
    'última etiqueta da viagem retorna a Minhas viagens com confirmação',
    (tester) async {
      final gateway = _FakeTripsGateway()
        ..listResults.addAll([
          [_summary()],
          [_summary()],
        ])
        ..getResults.addAll([_trip(completed: false), _trip(completed: true)])
        ..readResults.add(_accepted());
      final sessionController = SessionController(
        repository: FakeAuthGateway(),
        storage: MemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TripsScreen(
            sessionController: sessionController,
            tripsService: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ABRIR VIAGEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR PARADA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR PEDIDO'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'C');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Parada'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Pedido recepcionado com sucesso.'), findsOneWidget);
      final completedOrderCard = tester.widget<Card>(
        find.byKey(const ValueKey('order-card-17744')),
      );
      expect(completedOrderCard.color, const Color(0xFFFFF8D6));
      expect(find.text('Aguardando sincronização'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Minhas viagens'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Viagem'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Parada'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Pedido'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Carga concluída com sucesso.'), findsOneWidget);
      final completedTripCard = tester.widget<Card>(
        find.byKey(const ValueKey('trip-card-MANIFESTO')),
      );
      expect(completedTripCard.color, const Color(0xFFFFF8D6));
      expect(find.text('Aguardando sincronização'), findsNothing);
      expect(gateway.listCalls, 2);
      expect(gateway.getCalls, 2);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.text('Carga concluída com sucesso.'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Carga concluída com sucesso.'), findsNothing);
    },
  );

  testWidgets(
    'conclusão local mantém sequência Pedido/Carga e informa sincronização',
    (tester) async {
      final gateway = _FakeTripsGateway()
        ..pendingSync = true
        ..listResults.addAll([
          [_summary()],
          [_summary(locallyCompleted: true, awaitingSync: true)],
        ])
        ..getResults.addAll([_trip(completed: false), _trip(completed: true)])
        ..readResults.add(_accepted(awaitingSync: true));
      final sessionController = SessionController(
        repository: FakeAuthGateway(),
        storage: MemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TripsScreen(
            sessionController: sessionController,
            tripsService: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ABRIR VIAGEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR PARADA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR PEDIDO'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'C');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Pedido recepcionado com sucesso.'), findsOneWidget);
      expect(find.text('Aguardando sincronização.'), findsOneWidget);
      expect(
        tester
            .widget<Card>(find.byKey(const ValueKey('order-card-17744')))
            .color,
        const Color(0xFFE3F2FD),
      );
      expect(find.text('Aguardando sincronização'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.text('Pedido recepcionado com sucesso.'), findsNothing);
      expect(find.text('Carga concluída com sucesso.'), findsOneWidget);
      expect(find.text('Aguardando sincronização.'), findsOneWidget);
      expect(
        tester
            .widget<Card>(find.byKey(const ValueKey('trip-card-MANIFESTO')))
            .color,
        const Color(0xFFE3F2FD),
      );
      expect(find.text('Aguardando sincronização'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('confirmação da outbox atualiza Carga azul para amarelo', (
    tester,
  ) async {
    final gateway = _FakeTripsGateway()
      ..listResults.addAll([
        [_summary(locallyCompleted: true, awaitingSync: true)],
        [_summary(locallyCompleted: true)],
      ]);
    final syncEvents = _SyncEvents();
    final sessionController = SessionController(
      repository: FakeAuthGateway(),
      storage: MemorySessionStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TripsScreen(
          sessionController: sessionController,
          tripsService: gateway,
          syncEvents: syncEvents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Card>(find.byKey(const ValueKey('trip-card-MANIFESTO')))
          .color,
      const Color(0xFFE3F2FD),
    );
    expect(find.text('Aguardando sincronização'), findsOneWidget);

    syncEvents.emit();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Card>(find.byKey(const ValueKey('trip-card-MANIFESTO')))
          .color,
      const Color(0xFFFFF8D6),
    );
    expect(find.text('Aguardando sincronização'), findsNothing);
    expect(gateway.listCalls, 2);
  });
}

TripSummary _summary({
  bool locallyCompleted = false,
  bool awaitingSync = false,
}) {
  return TripSummary(
    manifestGuid: 'MANIFESTO',
    loadId: 527,
    description: 'TESTE',
    stopCount: 1,
    occurrenceCount: 1,
    locallyCompleted: locallyCompleted,
    awaitingSync: awaitingSync,
  );
}

TripDetail _trip({required bool completed}) {
  final status = completed ? 'E' : 'P';
  return TripDetail(
    manifestGuid: 'MANIFESTO',
    manifestStatus: 'L',
    loadId: 527,
    description: 'TESTE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    stops: [
      TripStop(
        id: 1,
        plannedOrder: 1,
        status: status,
        clientName: 'ÚLTIMO CLIENTE',
        city: 'Ubá',
        state: 'MG',
        address: '',
        orders: [TripOrder(id: 17744, status: status)],
        occurrences: [
          ManifestOccurrence(
            id: 1,
            guid: 'OC-17744',
            orderId: 17744,
            productId: 1004654,
            type: 'C',
            code: 'C1',
            quantity: '1',
            status: status,
          ),
        ],
      ),
    ],
    occurrenceCount: 1,
  );
}

DeliveryReadResult _accepted({bool awaitingSync = false}) {
  return DeliveryReadResult(
    result: 'ACEITA',
    responseCode: 'OK',
    message: 'Entrega registrada com sucesso.',
    replay: false,
    occurrenceGuid: 'OC-17744',
    orderId: 17744,
    pendingOrder: 0,
    pendingStop: 0,
    awaitingSync: awaitingSync,
  );
}

class _FakeTripsGateway
    implements TripsGateway, PendingSyncStatus, PendingOrderSyncStatus {
  final List<List<TripSummary>> listResults = [];
  final List<TripDetail> getResults = [];
  final List<DeliveryReadResult> readResults = [];
  int listCalls = 0;
  int getCalls = 0;
  bool pendingSync = false;

  @override
  Future<bool> hasPendingSync(String manifestGuid) async => pendingSync;

  @override
  Future<Set<int>> pendingSyncOrderIds({
    required String manifestGuid,
    required int stopId,
  }) async => pendingSync ? const {17744} : const {};

  @override
  Future<List<TripSummary>> list() async {
    listCalls++;
    return listResults.removeAt(0);
  }

  @override
  Future<TripDetail> get(String manifestGuid) async {
    getCalls++;
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

class _SyncEvents extends ChangeNotifier {
  void emit() => notifyListeners();
}
